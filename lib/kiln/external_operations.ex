defmodule Kiln.ExternalOperations do
  @moduledoc """
  Two-phase `intent → action → completion` idempotency table (D-14, D-18).
  Every external side-effect (LLM call, git push, Docker run, notify,
  secret resolve) funnels through this context so a retry after a crash
  between the intent insert and the action-start cannot re-do a
  completed action.

  Public API (locked contract):

    * `fetch_or_record_intent/2` — insert or read-through on the
      `idempotency_key` unique index; writes an `external_op_intent_recorded`
      audit event atomically with the INSERT (D-18).
    * `complete_op/2` — transition to `:completed` + append
      `external_op_completed` audit event in the same transaction.
    * `fail_op/2` — transition to `:failed` + append `external_op_failed`.
    * `abandon_op/2` — terminal state for Phase 5's `StuckDetector`.

  Every state-mutating call opens an `Ecto.Repo.transaction/1`, writes
  the state change + the companion audit event, and commits atomically.
  Callers MUST run the external side-effect *outside* this transaction
  (between `fetch_or_record_intent/2` and `complete_op/2`) so a failed
  remote call doesn't abort the audit row.
  """

  import Ecto.Query

  alias Kiln.Audit
  alias Kiln.ExternalOperations.Operation
  alias Kiln.Repo

  require Logger

  @doc """
  Insert a new intent row or return the existing one for the given
  `idempotency_key`. The `(idempotency_key)` UNIQUE INDEX on
  `external_operations` is the authoritative dedupe boundary (migration
  5); the Elixir path uses `INSERT ... ON CONFLICT DO NOTHING` plus a
  SELECT-FOR-UPDATE fallback to observe the winner deterministically
  (Brandur's pattern — https://brandur.org/idempotency-keys).

  Returns:

    * `{:inserted_new, op}` on first call for the key. An
      `external_op_intent_recorded` audit event was appended in the
      same transaction (D-18).
    * `{:found_existing, op}` when the key already had a row. No audit
      event is appended (the original intent's event is still in the
      ledger).
    * `{:error, changeset}` on validation failure (missing op_kind,
      etc.).

  `attrs` must include `:op_kind` (string, one of D-17 taxonomy) and
  may include `:intent_payload`, `:run_id`, `:stage_id`. The
  `:correlation_id` used for the audit pairing is read from
  `Logger.metadata` (set by `Kiln.Logger.Metadata.with_metadata/2`);
  tests may pass `:correlation_id` explicitly via `attrs`.
  """
  @spec fetch_or_record_intent(String.t(), map()) ::
          {:inserted_new, Operation.t()}
          | {:found_existing, Operation.t()}
          | {:error, Ecto.Changeset.t() | term()}
  def fetch_or_record_intent(idempotency_key, attrs) when is_binary(idempotency_key) do
    now = DateTime.utc_now()
    cid = attrs[:correlation_id] || Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

    insert_attrs =
      attrs
      |> Map.drop([:correlation_id])
      |> Map.put(:idempotency_key, idempotency_key)
      |> Map.put(:state, :intent_recorded)
      |> Map.put(:intent_recorded_at, now)

    Repo.transaction(fn ->
      changeset = Operation.changeset(%Operation{}, insert_attrs)

      # `on_conflict: :nothing` + `conflict_target: :idempotency_key`
      # makes racing callers safe: whichever writer gets the row first
      # wins, and all other writers see an unchanged `num_rows=0` return.
      # Because PK is populated by a Postgres DEFAULT (not Ecto
      # autogenerate), a successful INSERT returns the new %Operation{}
      # with `id` hydrated via the schema's `read_after_writes: true`;
      # a losing INSERT returns `%Operation{id: nil}` (no RETURNING row).
      case Repo.insert(changeset,
             on_conflict: :nothing,
             conflict_target: :idempotency_key
           ) do
        {:ok, %Operation{id: nil}} ->
          # Conflict — re-read with FOR UPDATE to observe the winner's row.
          op =
            Repo.one!(
              from(o in Operation,
                where: o.idempotency_key == ^idempotency_key,
                lock: "FOR UPDATE"
              )
            )

          {:found_existing, op}

        {:ok, %Operation{} = op} ->
          # First writer — append the paired intent audit event in the
          # SAME transaction (D-18). If the audit write fails (schema
          # rejection, unknown kind, etc.) the whole tx aborts and the
          # intent row is rolled back — invariant preserved.
          {:ok, _ev} =
            Audit.append(%{
              event_kind: :external_op_intent_recorded,
              run_id: op.run_id,
              stage_id: op.stage_id,
              correlation_id: cid,
              payload: %{
                "op_kind" => op.op_kind,
                "idempotency_key" => op.idempotency_key
              }
            })

          {:inserted_new, op}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Transition an op to `:completed` and append an `external_op_completed`
  audit event atomically (D-18). The `result_payload` is persisted on
  the row; a short `inspect`-based summary is placed in the audit
  event's `result_summary` field so the ledger stays readable without
  bloating.
  """
  @spec complete_op(Operation.t(), map()) ::
          {:ok, Operation.t()} | {:error, Ecto.Changeset.t() | term()}
  def complete_op(%Operation{} = op, result_payload) when is_map(result_payload) do
    cid = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

    Repo.transaction(fn ->
      changeset =
        Operation.changeset(op, %{
          state: :completed,
          result_payload: result_payload,
          completed_at: DateTime.utc_now()
        })

      case Repo.update(changeset) do
        {:ok, updated} ->
          {:ok, _ev} =
            Audit.append(%{
              event_kind: :external_op_completed,
              run_id: updated.run_id,
              stage_id: updated.stage_id,
              correlation_id: cid,
              payload: %{
                "op_kind" => updated.op_kind,
                "idempotency_key" => updated.idempotency_key,
                "result_summary" => summarize(result_payload)
              }
            })

          updated

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  @doc """
  Transition an op to `:failed` and append an `external_op_failed`
  audit event atomically (D-18). Increments the `attempts` counter on
  the row; the `error_map` is persisted on `last_error` and JSON-encoded
  into the audit event's `error` field.
  """
  @spec fail_op(Operation.t(), map()) ::
          {:ok, Operation.t()} | {:error, Ecto.Changeset.t() | term()}
  def fail_op(%Operation{} = op, error_map) when is_map(error_map) do
    cid = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

    Repo.transaction(fn ->
      changeset =
        Operation.changeset(op, %{
          state: :failed,
          last_error: error_map,
          attempts: op.attempts + 1
        })

      case Repo.update(changeset) do
        {:ok, updated} ->
          {:ok, _ev} =
            Audit.append(%{
              event_kind: :external_op_failed,
              run_id: updated.run_id,
              stage_id: updated.stage_id,
              correlation_id: cid,
              payload: %{
                "op_kind" => updated.op_kind,
                "idempotency_key" => updated.idempotency_key,
                "error" => Jason.encode!(error_map)
              }
            })

          updated

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  @doc """
  Abandon every still-open op for a run (`:intent_recorded` / `:action_in_flight`).
  Best-effort: failures on individual rows are logged and ignored so terminal
  run transitions still complete.
  """
  @spec abandon_open_for_run(Ecto.UUID.t(), String.t()) :: :ok
  def abandon_open_for_run(run_id, reason) when is_binary(reason) do
    from(o in Operation,
      where: o.run_id == ^run_id and o.state in [:intent_recorded, :action_in_flight]
    )
    |> Repo.all()
    |> Enum.each(fn op ->
      case abandon_op(op, reason) do
        {:ok, _} -> :ok
        {:error, err} -> Logger.warning("abandon_open_for_run: #{inspect(err)}")
      end
    end)

    :ok
  end

  @doc """
  Mark an op as `:abandoned` (intent without completion, found orphaned
  by Phase 5's `StuckDetector`). Uses the `external_op_failed` audit
  kind with an `"abandoned: <reason>"` prefix in the error field because
  the 22-kind taxonomy is locked at Phase 1 (D-08) and abandonment is
  conceptually a terminal failure mode from the ledger's perspective.
  """
  @spec abandon_op(Operation.t(), String.t()) ::
          {:ok, Operation.t()} | {:error, Ecto.Changeset.t() | term()}
  def abandon_op(%Operation{} = op, reason) when is_binary(reason) do
    cid = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

    Repo.transaction(fn ->
      changeset =
        Operation.changeset(op, %{
          state: :abandoned,
          last_error: %{"reason" => reason}
        })

      case Repo.update(changeset) do
        {:ok, updated} ->
          {:ok, _ev} =
            Audit.append(%{
              event_kind: :external_op_failed,
              run_id: updated.run_id,
              stage_id: updated.stage_id,
              correlation_id: cid,
              payload: %{
                "op_kind" => updated.op_kind,
                "idempotency_key" => updated.idempotency_key,
                "error" => "abandoned: #{reason}"
              }
            })

          updated

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  # Compact a result payload into a short human-readable string for the
  # audit ledger. `inspect(limit: 200)` covers maps + keywords + binaries
  # without blowing up on deeply-nested structures; the 500-char slice
  # is the upper bound the JSV schema doesn't enforce but the ledger
  # readability convention assumes.
  @spec summarize(map()) :: String.t()
  defp summarize(result) do
    result
    |> inspect(limit: 200)
    |> String.slice(0, 500)
  end
end
