defmodule Kiln.Workers.DogfoodPRWorker do
  @moduledoc """
  Oban worker for dogfood PR sync (`external_operations`, Phase 9).

  Idempotency key lives in args as `"idempotency_key"` (D-44 insert-time unique).
  """

  use Kiln.Oban.BaseWorker, queue: :github

  alias Kiln.GitHub.Dogfood

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with {:ok, key} <- fetch_str(args, "idempotency_key"),
         {:ok, paths} <- fetch_paths(args),
         :ok <- Dogfood.validate_changed_paths!(paths) do
      intent_attrs = %{
        op_kind: "dogfood_pr",
        intent_payload: Map.take(args, ["paths", "spec_hash"]),
        run_id: cast_uuid(args["run_id"]),
        stage_id: cast_uuid(args["stage_id"])
      }

      case fetch_or_record_intent(key, intent_attrs) do
        {:found_existing, %{state: :completed}} ->
          {:ok, :duplicate_suppressed}

        {:error, _} = err ->
          err

        {_ins, op} ->
          case Dogfood.sync_pr(args) do
            {:ok, meta} ->
              case complete_op(op, Map.new(meta, fn {k, v} -> {to_string(k), v} end)) do
                {:ok, _} -> {:ok, :completed}
                {:error, reason} -> {:error, reason}
              end

            {:error, :missing_github_token} ->
              _ = fail_op(op, %{"reason" => "missing_github_token"})
              {:cancel, :missing_github_token}

            {:error, reason} ->
              _ = fail_op(op, %{"reason" => inspect(reason)})
              {:error, reason}
          end
      end
    else
      {:error, _} = err -> err
    end
  end

  defp fetch_str(args, k) do
    case Map.get(args, k) do
      s when is_binary(s) and s != "" -> {:ok, s}
      _ -> {:error, {:missing_field, k}}
    end
  end

  defp fetch_paths(args) do
    case Map.get(args, "paths") do
      list when is_list(list) -> {:ok, Enum.map(list, &to_string/1)}
      _ -> {:error, {:missing_field, "paths"}}
    end
  end

  defp cast_uuid(nil), do: nil

  defp cast_uuid(s) when is_binary(s) do
    case Ecto.UUID.cast(s) do
      {:ok, u} -> u
      :error -> nil
    end
  end
end
