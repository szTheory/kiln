defmodule Kiln.Audit do
  @moduledoc """
  Append-only audit ledger. `append/1` is the only sanctioned entry point
  for writing to `audit_events`; `replay/1` is the read-side helper for
  replaying events back out.

  Three DB-level layers (REVOKE, trigger, RULE — D-12) reject UPDATE /
  DELETE / TRUNCATE against the table. `append/1` validates the payload
  against a per-kind JSON schema (JSV 0.18, Draft 2020-12) **before** the
  INSERT, so malformed events are rejected at the app boundary without a
  DB round-trip.

  Callers must pass `event_kind` (one of the values in
  `Kiln.Audit.EventKind.values/0`, including `:ci_status_observed` for
  Phase 6 GitHub delivery) and either pass `correlation_id`
  explicitly or have one set in `Logger.metadata` — an `ArgumentError`
  is raised otherwise so the causal chain is never silently dropped.
  """

  import Ecto.Query

  alias Kiln.Audit.Event
  alias Kiln.Audit.EventKind
  alias Kiln.Audit.SchemaRegistry
  alias Kiln.Repo

  require Logger

  @doc """
  Append a new audit event.

  Returns `{:ok, event}` when the payload is valid and the INSERT
  succeeds. Returns `{:error, {:audit_payload_invalid, details}}` when
  the payload fails schema validation (no DB write),
  `{:error, {:unknown_event_kind, kind}}` when the kind is outside the
  taxonomy, `{:error, {:audit_schema_missing, kind}}` when the
  per-kind JSON schema isn't loadable, and `{:error, changeset}` if the
  Ecto changeset fails (e.g. missing required fields).

  `correlation_id`, `schema_version`, and `occurred_at` are filled from
  `Logger.metadata` / constants / wall-clock when not provided on the
  attrs map.
  """
  @spec append(map()) ::
          {:ok, Event.t()}
          | {:error,
             {:audit_payload_invalid, term()}
             | {:unknown_event_kind, term()}
             | {:audit_schema_missing, atom()}
             | Ecto.Changeset.t()}
  def append(%{event_kind: kind} = attrs) when is_atom(kind) do
    if EventKind.valid?(kind) do
      append_validated(kind, attrs)
    else
      {:error, {:unknown_event_kind, kind}}
    end
  end

  def append(%{event_kind: kind_str} = attrs) when is_binary(kind_str) do
    case Enum.find(EventKind.values(), &(Atom.to_string(&1) == kind_str)) do
      nil -> {:error, {:unknown_event_kind, kind_str}}
      kind -> append(Map.put(attrs, :event_kind, kind))
    end
  end

  @doc """
  Replay audit events, optionally filtered by `run_id`, `event_kind`,
  or `correlation_id`. Returns a list ordered by `occurred_at` ascending
  so downstream consumers see events in causal order.
  """
  @spec replay(keyword()) :: [Event.t()]
  def replay(opts \\ []) do
    {limit, filters} = Keyword.pop(opts, :limit, 500)

    Event
    |> from(as: :e)
    |> order_by([e: e], asc: e.occurred_at)
    |> apply_replay_filters(filters)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Keyset page through audit events for a single run in canonical order
  (`ORDER BY occurred_at ASC, id ASC`).

  Options:

    * `:run_id` — required run UUID
    * `:limit` — positive page size
    * `:after` — `nil` (default) or `{DateTime.t(), id}` cursor; the next
      page starts strictly after this `(occurred_at, id)` pair
    * `:anchor` — `:head` (default) walks forward from the earliest row;
      `:tail` returns the latest `limit` rows (still ascending in the result)

  `truncated` is true when at least one more row exists after the returned
  page in forward chronological order.
  """
  @spec replay_page(keyword()) :: %{events: [Event.t()], truncated: boolean()}
  def replay_page(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    limit = Keyword.fetch!(opts, :limit)

    unless is_integer(limit) and limit > 0 do
      raise ArgumentError, "replay_page :limit must be a positive integer"
    end

    case Keyword.get(opts, :anchor, :head) do
      :tail -> replay_page_tail(run_id, limit)
      :head -> replay_page_forward(run_id, limit, Keyword.get(opts, :after, nil))
    end
  end

  # -- private -------------------------------------------------------------

  defp apply_replay_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:run_id, rid}, acc -> where(acc, [e: e], e.run_id == ^rid)
      {:event_kind, k}, acc -> where(acc, [e: e], e.event_kind == ^k)
      {:correlation_id, c}, acc -> where(acc, [e: e], e.correlation_id == ^c)
      {:stage_id, id}, acc -> where(acc, [e: e], e.stage_id == ^id)
      {:actor_role, role}, acc when role in [nil, ""] -> acc
      {:actor_role, role}, acc -> where(acc, [e: e], e.actor_role == ^role)
      {:occurred_after, %DateTime{} = dt}, acc -> where(acc, [e: e], e.occurred_at >= ^dt)
      {:occurred_before, %DateTime{} = dt}, acc -> where(acc, [e: e], e.occurred_at <= ^dt)
      _other, acc -> acc
    end)
  end

  defp append_validated(kind, attrs) do
    with {:ok, root} <- SchemaRegistry.fetch(kind),
         :ok <- validate_payload(root, Map.get(attrs, :payload, %{})) do
      insert_event(attrs)
    else
      {:error, :schema_missing} -> {:error, {:audit_schema_missing, kind}}
      {:error, {:audit_payload_invalid, _} = reason} -> {:error, reason}
    end
  end

  defp validate_payload(root, payload) do
    case JSV.validate(payload, root) do
      {:ok, _casted} -> :ok
      {:error, %JSV.ValidationError{} = err} -> {:error, {:audit_payload_invalid, err}}
      {:error, other} -> {:error, {:audit_payload_invalid, other}}
    end
  end

  defp insert_event(attrs) do
    attrs =
      attrs
      |> Map.put_new_lazy(:correlation_id, &correlation_id_from_logger/0)
      |> Map.put_new(:schema_version, 1)
      |> Map.put_new(:occurred_at, DateTime.utc_now())

    changeset =
      %Event{}
      |> Ecto.Changeset.cast(attrs, [
        :event_kind,
        :actor_id,
        :actor_role,
        :run_id,
        :stage_id,
        :correlation_id,
        :causation_id,
        :schema_version,
        :payload,
        :occurred_at
      ])
      |> Ecto.Changeset.validate_required([:event_kind, :correlation_id])

    case Repo.insert(changeset) do
      {:ok, %Event{run_id: rid} = event} when not is_nil(rid) ->
        _ = Phoenix.PubSub.broadcast(Kiln.PubSub, "audit:run:#{rid}", {:audit_event, event})

        {:ok, event}

      other ->
        other
    end
  end

  defp replay_page_forward(run_id, limit, after_cursor) do
    base =
      from e in Event,
        where: e.run_id == ^run_id,
        order_by: [asc: e.occurred_at, asc: e.id]

    filtered =
      case after_cursor do
        nil ->
          base

        {%DateTime{} = dt, id} ->
          from e in base,
            where:
              e.occurred_at > ^dt or
                (e.occurred_at == ^dt and e.id > ^id)
      end

    take = limit + 1

    rows =
      filtered
      |> limit(^take)
      |> Repo.all()

    if length(rows) > limit do
      %{events: Enum.take(rows, limit), truncated: true}
    else
      %{events: rows, truncated: false}
    end
  end

  defp replay_page_tail(run_id, limit) do
    rows_desc =
      from(e in Event,
        where: e.run_id == ^run_id,
        order_by: [desc: e.occurred_at, desc: e.id],
        limit: ^limit
      )
      |> Repo.all()

    events = Enum.reverse(rows_desc)
    oldest = List.first(events)

    truncated =
      oldest &&
        Repo.exists?(
          from e in Event,
            where: e.run_id == ^run_id,
            where:
              e.occurred_at < ^oldest.occurred_at or
                (e.occurred_at == ^oldest.occurred_at and e.id < ^oldest.id)
        )

    %{events: events, truncated: truncated || false}
  end

  defp correlation_id_from_logger do
    case Logger.metadata()[:correlation_id] do
      nil ->
        raise ArgumentError,
              "Kiln.Audit.append/1 requires a correlation_id — pass it explicitly " <>
                "or set Logger.metadata(:correlation_id, uuid) on the calling process."

      cid ->
        cid
    end
  end
end
