defmodule Kiln.Runs.Transitions do
  @moduledoc """
  The canonical command module for run state transitions (D-86..D-91).

  `transition/3` is the SOLE sanctioned path for changing `runs.state`.
  Every call opens a single `Repo.transact/2`, takes a
  `SELECT ... FOR UPDATE` lock on the run row, asserts the attempted
  edge is allowed by the D-87 matrix, invokes the
  `Kiln.Policies.StuckDetector.check/1` hook (no-op in Phase 2 per D-91;
  sliding-window body in Phase 5), updates the `state` column via
  `Run.transition_changeset/3`, and appends a paired
  `:run_state_transitioned` audit event — all atomically. The PubSub
  broadcast fires AFTER `Repo.transact/2` returns `{:ok, _}`; broadcasting
  inside the closure would announce a state change the DB could still
  roll back.

  The D-87 matrix is encoded as a MODULE ATTRIBUTE `@matrix` (data, not
  pattern-matched function heads) so it can be inspected from iex,
  serialised to an operator UI later (Phase 7), and round-tripped in
  tests without reflection. Cross-cutting edges
  (any non-terminal state → `:escalated` / `:failed`) live in
  `@cross_cutting` and are unioned with the per-state allow-list at
  assertion time.

  Terminal states (`:merged`, `:failed`, `:escalated`) reject every
  outgoing transition: the only legal state change for a terminal row
  is "none".

  Threat-model note (T1 in PLAN.md): a developer who calls
  `Run.transition_changeset/3 |> Repo.update/1` directly bypasses this
  module and writes a state change with no audit event. The D-12
  three-layer audit immutability prevents tampering with the ledger
  after the fact, but does NOT force callers through this module.
  Long-term mitigation is a Credo check
  (`NoDirectRunStateUpdate`) scoped to a Phase 3+ hardening plan;
  interim mitigation is PR review.
  """

  import Ecto.Query
  require Logger
  alias Kiln.{AgentTickerRateLimiter, Audit, Repo}
  alias Kiln.ExternalOperations
  alias Kiln.Runs.Run
  alias Kiln.Policies.StuckDetector
  alias Kiln.Telemetry.Spans

  @terminal ~w(merged failed escalated)a
  @any_state ~w(queued planning coding testing verifying blocked)a

  # D-87 — allowed forward edges for each non-terminal state. The
  # terminal cross-cutting pair (`:escalated`/`:failed`) is UNION'd
  # onto every entry at assertion time, so callers don't need to list
  # those twice.
  @matrix %{
    queued: [:planning],
    planning: [:coding, :blocked],
    # coder-fail routes back to planner
    coding: [:testing, :blocked, :planning],
    # tester-fail routes back to planner
    testing: [:verifying, :blocked, :planning],
    # verifier-fail re-plans
    verifying: [:merged, :planning, :blocked],
    # resume from checkpoint
    blocked: [:planning, :coding, :testing, :verifying]
  }

  # Cross-cutting: every @any_state can reach @cross_cutting
  # (stuck-detector / cap-exceeded / unrecoverable).
  @cross_cutting ~w(escalated failed)a

  @doc """
  Attempt to transition the run identified by `run_id` into state `to`.

  Returns:

    * `{:ok, %Run{}}` — the state change and paired audit event
      committed atomically; PubSub broadcasts have been sent to the
      `"run:<id>"` and `"runs:board"` topics.
    * `{:error, :illegal_transition}` — the attempted edge is not in
      the D-87 matrix (or the `:from` state is terminal). No state
      change, no audit event, no broadcast.
    * `{:error, :not_found}` — no row for `run_id`. Raised from inside
      the transaction but returned as a tuple.
    * `{:error, term}` — any other Ecto / Audit error surfaces
      unchanged.

  `meta` is an optional map that MAY carry `:reason` (an atom — the
  typed block reason from BLOCK-01 in Phase 3; stored in the audit
  payload as a string via `Atom.to_string/1`). Non-atom `:reason` is
  silently dropped so the audit payload never accepts unvalidated
  string data (threat-model T5).
  """
  @spec transition(Ecto.UUID.t(), atom(), map()) ::
          {:ok, Run.t()} | {:error, :illegal_transition | :not_found | term()}
  def transition(run_id, to, meta \\ %{}) when is_atom(to) do
    rid = to_string(run_id)

    Spans.with_run_stage(
      %{run_id: rid, "transition.to": Atom.to_string(to)},
      fn ->
        result =
          Repo.transact(fn ->
            with {:ok, run} <- lock_run(run_id),
                 :ok <- assert_allowed(run.state, to) do
              case maybe_escalate_caps(run, to, meta) do
                {:escalate, reason} ->
                  escalate_in_tx(run, reason, meta)

                :ok ->
                  case StuckDetector.check(%{run: run, to: to, meta: meta}) do
                    {:halt, :stuck, halt} ->
                      escalate_stuck_in_tx(run, halt, meta)

                    {:ok, new_window} ->
                      transition_ok(run, to, meta, new_window)
                  end
              end
            end
          end)

        # CRITICAL: PubSub broadcast AFTER tx commits — never inside the
        # closure. Broadcasting from within the transaction risks announcing
        # a state change the DB could still roll back (Pitfall #1 in
        # RESEARCH.md; D-90).
        case result do
          {:ok, run} ->
            maybe_abandon_ops(run)
            Phoenix.PubSub.broadcast(Kiln.PubSub, "run:#{run.id}", {:run_state, run})
            Phoenix.PubSub.broadcast(Kiln.PubSub, "runs:board", {:run_state, run})
            maybe_broadcast_agent_ticker(run, meta)
            {:ok, run}

          other ->
            other
        end
      end
    )
  end

  @doc """
  Imperative variant — raises `Kiln.Runs.IllegalTransitionError` on
  `{:error, :illegal_transition}` or `{:error, :not_found}`. Reserved
  for tests and admin tools (`mix kiln.admin.force_state`); production
  code should prefer `transition/3` so illegal transitions surface as
  tuples and can be routed to retry / escalate / drop paths without
  burning an Oban attempt on a backtrace.
  """
  @spec transition!(Ecto.UUID.t(), atom(), map()) :: Run.t()
  def transition!(run_id, to, meta \\ %{}) do
    case transition(run_id, to, meta) do
      {:ok, run} ->
        run

      {:error, :illegal_transition} ->
        run = Repo.get(Run, run_id)
        from = run && run.state
        allowed = if from, do: Map.get(@matrix, from, []) ++ @cross_cutting, else: []

        raise Kiln.Runs.IllegalTransitionError,
          run_id: run_id,
          from: from,
          to: to,
          allowed: allowed

      {:error, :not_found} ->
        raise Kiln.Runs.IllegalTransitionError,
          run_id: run_id,
          from: :not_found,
          to: to,
          allowed: []

      {:error, reason} ->
        raise "Kiln.Runs.Transitions.transition!/3 error: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the D-87 allowed-edge matrix as data — keyed by the six
  non-terminal states (`Kiln.Runs.Run.active_states/0`). The terminal
  cross-cutting edges (`:escalated`, `:failed`) are NOT in the
  per-state value lists; they are unioned at `assert_allowed/2` time.
  Exposed for tests, LiveView diagrams (Phase 7), and iex
  introspection.
  """
  @spec matrix() :: %{atom() => [atom()]}
  def matrix, do: @matrix

  # -- private helpers ----------------------------------------------------

  defp lock_run(run_id) do
    case Repo.one(from(r in Run, where: r.id == ^run_id, lock: "FOR UPDATE")) do
      nil -> {:error, :not_found}
      run -> {:ok, run}
    end
  end

  defp assert_allowed(from, to) do
    cond do
      from in @terminal -> {:error, :illegal_transition}
      to in (Map.get(@matrix, from, []) ++ @cross_cutting) -> :ok
      true -> {:error, :illegal_transition}
    end
  end

  defp update_state(run, to, meta) do
    attrs = %{state: to}

    attrs =
      case meta do
        %{reason: r} when to in @cross_cutting and is_atom(r) ->
          Map.put(attrs, :escalation_reason, Atom.to_string(r))

        _ ->
          attrs
      end

    attrs =
      case meta do
        %{stuck_signal_window: w} when is_list(w) ->
          Map.put(attrs, :stuck_signal_window, w)

        _ ->
          attrs
      end

    attrs =
      case meta do
        %{diagnostic: d} when is_map(d) ->
          Map.put(attrs, :escalation_detail, d)

        _ ->
          attrs
      end

    attrs =
      if meta[:skip_governed_increment] == true do
        attrs
      else
        Map.put(attrs, :governed_attempt_count, next_governed_count(run, to))
      end

    run
    |> Run.transition_changeset(attrs, meta)
    |> Repo.update()
  end

  defp next_governed_count(run, to) do
    if to == :planning and run.state in [:coding, :testing, :verifying] do
      run.governed_attempt_count + 1
    else
      run.governed_attempt_count
    end
  end

  defp maybe_escalate_caps(_run, _to, %{skip_cap_checks: true}), do: :ok

  defp maybe_escalate_caps(run, to, _meta) do
    cond do
      wall_clock_exceeded?(run) ->
        {:escalate, :wall_clock_exceeded}

      governed_cap_exceeded?(run, to) ->
        {:escalate, :governed_attempt_cap}

      true ->
        :ok
    end
  end

  defp wall_clock_exceeded?(run) do
    max_s = caps_get(run.caps_snapshot, "max_elapsed_seconds")

    if is_integer(max_s) and max_s >= 0 do
      DateTime.diff(DateTime.utc_now(), run.inserted_at, :second) > max_s
    else
      false
    end
  end

  defp governed_cap_exceeded?(run, to) do
    max_g = caps_get(run.caps_snapshot, "max_governed_attempts")

    bump? = to == :planning and run.state in [:coding, :testing, :verifying]

    if is_integer(max_g) and bump? and run.governed_attempt_count + 1 > max_g do
      true
    else
      false
    end
  end

  defp caps_get(snapshot, key) when is_map(snapshot) do
    Map.get(snapshot, key) || Map.get(snapshot, String.to_atom(key))
  end

  defp caps_get(_, _), do: nil

  defp escalate_in_tx(run, reason, meta) do
    meta =
      meta
      |> Map.put(:reason, reason)
      |> Map.put(:skip_governed_increment, true)

    with :ok <- assert_allowed(run.state, :escalated),
         {:ok, updated} <- update_state(run, :escalated, meta),
         {:ok, _} <- append_audit(updated, run.state, :escalated, meta) do
      {:ok, updated}
    end
  end

  defp escalate_stuck_in_tx(run, halt, meta) do
    halt = Map.new(halt)

    meta =
      meta
      |> Map.put(:reason, :stuck)
      |> Map.put(:skip_governed_increment, true)
      |> Map.put(:stuck_signal_window, Map.fetch!(halt, :stuck_signal_window))
      |> Map.put(:stuck_detail, Map.drop(halt, [:stuck_signal_window]))

    with :ok <- assert_allowed(run.state, :escalated),
         {:ok, updated} <- update_state(run, :escalated, meta),
         {:ok, _} <- append_audit(updated, run.state, :escalated, meta),
         {:ok, _} <- append_stuck_alarm(updated, halt) do
      {:ok, updated}
    end
  end

  defp transition_ok(run, to, meta, new_window) do
    meta = Map.put(meta, :stuck_signal_window, new_window)

    with {:ok, updated} <- update_state(run, to, meta),
         {:ok, _} <- append_audit(updated, run.state, to, meta) do
      {:ok, updated}
    end
  end

  defp append_stuck_alarm(run, halt) do
    halt = Map.new(halt)
    fc = halt |> Map.fetch!(:failure_class) |> to_string()

    Audit.append(%{
      event_kind: :stuck_detector_alarmed,
      run_id: run.id,
      correlation_id: Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
      payload: %{
        "failure_class" => fc,
        "count" => Map.fetch!(halt, :occurrences)
      }
    })
  end

  defp maybe_abandon_ops(%Run{state: s} = run) when s in [:failed, :escalated] do
    _ = ExternalOperations.abandon_open_for_run(run.id, Atom.to_string(s))
    :ok
  end

  defp maybe_abandon_ops(_), do: :ok

  defp append_audit(run, from, to, meta) do
    payload =
      %{"from" => Atom.to_string(from), "to" => Atom.to_string(to)}
      |> maybe_add_reason(meta)

    Audit.append(%{
      event_kind: :run_state_transitioned,
      run_id: run.id,
      correlation_id: Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
      payload: payload
    })
  end

  defp maybe_add_reason(payload, %{reason: r}) when is_atom(r) and not is_nil(r),
    do: Map.put(payload, "reason", Atom.to_string(r))

  defp maybe_add_reason(payload, _), do: payload

  defp maybe_broadcast_agent_ticker(%Run{} = run, meta) do
    stage_id = Map.get(meta, :stage_id, Atom.to_string(run.state))

    line =
      [
        String.slice(to_string(run.id), 0, 8),
        Atom.to_string(run.state),
        run.workflow_id
      ]
      |> Enum.join(" · ")

    if AgentTickerRateLimiter.allow?(run.id) do
      Phoenix.PubSub.broadcast(
        Kiln.PubSub,
        "agent_ticker",
        {:agent_ticker_line, %{run_id: run.id, stage_id: stage_id, line: line}}
      )
    end

    :ok
  end

  # @any_state is referenced in the moduledoc narrative — keep the
  # module attribute resident so dialyxir doesn't flag it, and future
  # readers can discover the six-state partition without grepping
  # `Run.active_states/0`.
  @doc false
  def __any_state__, do: @any_state
end
