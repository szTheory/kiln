defmodule Kiln.OperatorNudges do
  @moduledoc """
  FEEDBACK-01 — operator nudge accept path + planning-stage consumption.
  """

  import Ecto.Query

  alias Kiln.{Audit, Repo}
  alias Kiln.Audit.Event
  alias Kiln.Runs.Run

  require Logger

  @default_grapheme_cap 180

  @doc """
  Persists an `operator_feedback_received` audit row. Does not advance
  `runs.operator_nudge_last_audit_id` — consumption does that at planning boundary.
  """
  @spec submit(Ecto.UUID.t(), String.t(), keyword()) ::
          {:ok, Ecto.UUID.t()} | {:error, atom() | term()}
  def submit(run_id, body, opts \\ []) when is_binary(run_id) and is_binary(body) do
    utc_now_fun = Keyword.get(opts, :utc_now, &DateTime.utc_now/0)
    now = utc_now_fun.()
    now_unix = DateTime.to_unix(now, :second)

    with {:ok, cleaned} <- normalize_and_validate(body, opts),
         :ok <- Kiln.OperatorNudgeLimiter.check(run_id, now_unix) do
      graphemes = String.graphemes(cleaned)
      preview = graphemes |> Enum.take(256) |> Enum.join()

      payload = %{
        "body_preview" => preview,
        "grapheme_count" => Integer.to_string(length(graphemes))
      }

      cid = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

      case Repo.transact(fn ->
             case Audit.append(%{
                    event_kind: :operator_feedback_received,
                    run_id: run_id,
                    correlation_id: cid,
                    payload: payload
                  }) do
               {:ok, %Event{id: id}} -> {:ok, id}
               {:error, reason} -> Repo.rollback(reason)
             end
           end) do
        {:ok, audit_id} ->
          _ = Kiln.OperatorNudgeLimiter.record_accept(run_id, now_unix)

          :telemetry.execute(
            [:kiln, :operator, :nudge, :received],
            %{count: 1},
            %{run_id: run_id}
          )

          {:ok, audit_id}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Locks the run, drains up to 50 pending `operator_feedback_received` audits
  after the consumption cursor, and advances `operator_nudge_last_audit_id`.
  """
  @spec consume_pending_for_planning(Ecto.UUID.t()) ::
          {:ok, [map()]} | {:error, term()}
  def consume_pending_for_planning(run_id) when is_binary(run_id) do
    Repo.transact(fn ->
      case Repo.one(from(r in Run, where: r.id == ^run_id, lock: "FOR UPDATE")) do
        nil ->
          Repo.rollback(:not_found)

        %Run{} = run ->
          base =
            from(e in Event,
              where: e.run_id == ^run_id,
              where: e.event_kind == :operator_feedback_received,
              order_by: [asc: e.id],
              limit: 50
            )

          q =
            if is_nil(run.operator_nudge_last_audit_id) do
              base
            else
              from e in base, where: e.id > ^run.operator_nudge_last_audit_id
            end

          rows = Repo.all(q)

          previews =
            Enum.map(rows, fn %Event{payload: p} ->
              bp = Map.get(p, "body_preview") || Map.get(p, :body_preview) || ""
              %{"body_preview" => bp}
            end)

          if rows != [] do
            max_id = rows |> Enum.map(& &1.id) |> Enum.max()

            run
            |> Run.nudge_cursor_changeset(%{operator_nudge_last_audit_id: max_id})
            |> Repo.update!()
          end

          {:ok, previews}
      end
    end)
  end

  defp normalize_and_validate(body, opts) do
    cap = Keyword.get(opts, :grapheme_cap, default_grapheme_cap())
    cleaned = normalize_body(body)

    cond do
      cleaned == "" ->
        {:error, :empty_body}

      length(String.graphemes(cleaned)) > cap ->
        {:error, :body_too_long}

      true ->
        {:ok, cleaned}
    end
  end

  defp default_grapheme_cap do
    Application.get_env(:kiln, __MODULE__, [])
    |> Keyword.get(:grapheme_cap, @default_grapheme_cap)
  end

  defp normalize_body(body) when is_binary(body) do
    body
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F]/u, "")
    |> String.trim()
  end
end
