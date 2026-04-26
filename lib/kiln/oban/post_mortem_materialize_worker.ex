defmodule Kiln.Oban.PostMortemMaterializeWorker do
  @moduledoc """
  Async post-mortem snapshot materialization (Phase 19). Aggregates
  `stage_runs` + audit watermark into `run_postmortems.snapshot`.
  """

  use Kiln.Oban.BaseWorker, queue: :default

  import Ecto.Query

  alias Kiln.{Audit, Repo}
  alias Kiln.Audit.Event
  alias Kiln.Runs.{PostMortems, Run}
  alias Kiln.Stages.StageRun

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, meta: meta}) do
    _ = maybe_unpack_ctx(meta)

    case parse_args(args) do
      {:ok, run_id, key} ->
        do_perform(run_id, key)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_perform(run_id, key) do
    case fetch_or_record_intent(key, %{
           op_kind: "post_mortem_materialize",
           intent_payload: %{"run_id" => run_id, "idempotency_key" => key},
           run_id: run_id
         }) do
      {:found_existing, %{state: :completed}} ->
        :ok

      {:error, _} = err ->
        err

      {_status, op} ->
        case materialize(run_id) do
          {:ok, snapshot, watermark} ->
            attrs = %{
              schema_version: "1",
              status: :complete,
              source_watermark: watermark,
              snapshot: snapshot
            }

            case PostMortems.upsert_snapshot(run_id, attrs) do
              {:ok, _} ->
                _ = maybe_audit_echo(run_id, watermark)
                _ = complete_op(op, %{"result" => "snapshot_ok"})
                :ok

              {:error, cs} ->
                _ = fail_op(op, %{"reason" => "upsert_failed", "detail" => inspect(cs.errors)})
                {:error, cs}
            end

          {:error, reason} ->
            _ = fail_op(op, %{"reason" => inspect(reason)})
            {:error, reason}
        end
    end
  end

  defp parse_args(%{"run_id" => rid, "idempotency_key" => key})
       when is_binary(rid) and is_binary(key),
       do: {:ok, rid, key}

  defp parse_args(_), do: {:error, :bad_args}

  defp materialize(run_id) do
    run = Repo.get(Run, run_id)

    cond do
      is_nil(run) ->
        {:error, :run_not_found}

      true ->
        stages =
          from(sr in StageRun,
            where: sr.run_id == ^run_id,
            order_by: [asc: sr.inserted_at, asc: sr.id],
            select: %{
              workflow_stage_id: sr.workflow_stage_id,
              requested_model: sr.requested_model,
              actual_model_used: sr.actual_model_used
            }
          )
          |> Repo.all()
          |> Enum.map(&stringify_keys/1)

        max_occurred =
          Repo.one(
            from(e in Event,
              where: e.run_id == ^run_id,
              select: max(e.occurred_at)
            )
          )

        max_id =
          Repo.one(
            from(e in Event,
              where: e.run_id == ^run_id,
              order_by: [desc: e.id],
              limit: 1,
              select: e.id
            )
          )

        watermark =
          case max_occurred do
            %DateTime{} = dt -> DateTime.to_iso8601(dt)
            _ -> ""
          end

        max_audit_str = if(max_id, do: to_string(max_id), else: "")

        snapshot = %{
          "stages" => stages,
          "source_watermark" => watermark,
          "max_audit_id" => max_audit_str,
          "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }

        {:ok, snapshot, watermark}
    end
  end

  defp stringify_keys(%{
         workflow_stage_id: w,
         requested_model: rm,
         actual_model_used: am
       }) do
    %{
      "workflow_stage_id" => w,
      "requested_model" => rm,
      "actual_model_used" => am
    }
  end

  defp maybe_audit_echo(run_id, watermark) do
    run = Repo.get!(Run, run_id)

    payload = %{
      "schema_version" => "1",
      "source_watermark" => watermark,
      "run_id" => to_string(run_id)
    }

    case Audit.append(%{
           event_kind: :post_mortem_snapshot_stored,
           run_id: run_id,
           correlation_id: correlation_id_for_audit(run),
           payload: payload
         }) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("post_mortem audit echo skipped: #{inspect(reason)}")
    end
  end

  defp maybe_unpack_ctx(%{"kiln_ctx" => ctx}) when is_map(ctx) and map_size(ctx) > 0 do
    Kiln.Telemetry.unpack_ctx(ctx)
  end

  defp maybe_unpack_ctx(_), do: :ok

  defp correlation_id_for_audit(%Run{} = run) do
    Logger.metadata()[:correlation_id] || run.correlation_id || Ecto.UUID.generate()
  end
end
