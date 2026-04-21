defmodule Kiln.GitHub.CheckPoller do
  @moduledoc """
  Oban worker for `gh_check_observe` — polls GitHub check runs until
  terminal (`predicate_pass` or a required check fails definitively).

  Pending CI returns `{:snooze, 15}` so Oban reschedules the same job
  without burning `max_attempts` as a wait loop (D-G10).
  """

  use Kiln.Oban.BaseWorker, queue: :github

  alias Kiln.GitHub.{Checks, Cli}

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, meta: meta}) do
    _ = maybe_unpack_ctx(meta)

    with {:ok, parsed} <- parse_args(args),
         :ok <- assert_expected_key(parsed) do
      do_poll(parsed)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_poll(parsed) do
    case fetch_or_record_intent(parsed.idempotency_key, %{
           op_kind: "gh_check_observe",
           intent_payload: parsed.intent_snapshot,
           run_id: parsed.run_id,
           stage_id: parsed.stage_id
         }) do
      {:found_existing, %{state: :completed}} ->
        {:ok, :already_done}

      {:error, _} = err ->
        err

      {_ins, op} ->
        case Cli.list_check_runs(parsed.repo, parsed.pr_number, runner: cli_runner()) do
          {:ok, json} ->
            case Checks.summarize(json, %{
                   required_check_names: parsed.required_names,
                   is_draft: parsed.is_draft
                 }) do
              {:ok, summary} ->
                cond do
                  summary.predicate_pass or required_failed?(summary.required) ->
                    case complete_op(op, %{
                           "head_sha" => summary.head_sha,
                           "predicate_pass" => summary.predicate_pass,
                           "required" => Enum.map(summary.required, &check_row_to_map/1),
                           "optional" => Enum.map(summary.optional, &check_row_to_map/1)
                         }) do
                      {:ok, _} -> {:ok, :completed}
                      {:error, reason} -> {:error, reason}
                    end

                  true ->
                    {:snooze, 15}
                end

              {:error, :checks_transport_unsupported} ->
                _ =
                  fail_op(op, %{
                    "reason" => "checks_transport_unsupported"
                  })

                {:cancel, :checks_transport_unsupported}
            end

          {:error, %{} = raw} ->
            _ = fail_op(op, %{"reason" => "gh_api", "detail" => inspect(raw)})
            {:error, :gh_cli_failed}

          {:error, reason} when is_atom(reason) ->
            case reason do
              :gh_auth_expired ->
                {:cancel, reason}

              :gh_permissions_insufficient ->
                {:cancel, reason}

              _ ->
                _ = fail_op(op, %{"reason" => Atom.to_string(reason)})
                {:error, reason}
            end
        end
    end
  end

  defp check_row_to_map(%{id: id, name: name, conclusion: c, status: st}) do
    %{"id" => id, "name" => name, "conclusion" => c, "status" => st}
  end

  defp required_failed?(required) do
    Enum.any?(required, fn %{conclusion: c, status: st} ->
      st == "completed" and c != nil and c not in ["success", "skipped", "neutral"]
    end)
  end

  defp parse_args(args) do
    with {:ok, idempotency_key} <- fetch_str(args, "idempotency_key"),
         {:ok, run_id} <- cast_uuid(args, "run_id"),
         {:ok, stage_id} <- cast_uuid(args, "stage_id"),
         {:ok, repo} <- fetch_str(args, "repo"),
         {:ok, pr_number} <- fetch_int(args, "pr_number"),
         {:ok, head_sha} <- fetch_str(args, "head_sha"),
         {:ok, required_names} <- fetch_string_list(args, "required_check_names"),
         {:ok, is_draft} <- fetch_bool(args, "is_draft") do
      {:ok,
       %{
         idempotency_key: idempotency_key,
         run_id: run_id,
         stage_id: stage_id,
         repo: repo,
         pr_number: pr_number,
         head_sha: head_sha,
         required_names: required_names,
         is_draft: is_draft,
         intent_snapshot:
           Map.take(args, [
             "repo",
             "pr_number",
             "head_sha",
             "required_check_names",
             "is_draft"
           ])
       }}
    end
  end

  defp assert_expected_key(parsed) do
    pr = Integer.to_string(parsed.pr_number)
    want = "run:#{parsed.run_id}:pr:#{pr}:sha:#{parsed.head_sha}:gh_check_observe"

    if parsed.idempotency_key == want do
      :ok
    else
      {:error, {:bad_idempotency_key, want, parsed.idempotency_key}}
    end
  end

  defp fetch_str(m, k) do
    case Map.get(m, k) do
      v when is_binary(v) and v != "" -> {:ok, v}
      _ -> {:error, {:missing, k}}
    end
  end

  defp cast_uuid(m, k) do
    case Ecto.UUID.cast(Map.get(m, k)) do
      {:ok, u} -> {:ok, u}
      :error -> {:error, {:bad_uuid, k}}
    end
  end

  defp fetch_int(m, k) do
    case Map.get(m, k) do
      n when is_integer(n) ->
        {:ok, n}

      b when is_binary(b) ->
        case Integer.parse(b) do
          {n, ""} -> {:ok, n}
          _ -> {:error, {:bad_int, k}}
        end

      _ ->
        {:error, {:bad_int, k}}
    end
  end

  defp fetch_string_list(m, k) do
    case Map.get(m, k) do
      list when is_list(list) ->
        if Enum.all?(list, &is_binary/1) do
          {:ok, list}
        else
          {:error, {:bad_string_list, k}}
        end

      _ ->
        {:error, {:bad_string_list, k}}
    end
  end

  defp fetch_bool(m, k) do
    case Map.get(m, k) do
      b when is_boolean(b) -> {:ok, b}
      _ -> {:error, {:bad_bool, k}}
    end
  end

  defp cli_runner do
    Application.get_env(:kiln, __MODULE__, [])
    |> Keyword.get(:cli_runner, Cli.default_runner())
  end

  defp maybe_unpack_ctx(%{"kiln_ctx" => ctx}) when is_map(ctx) and map_size(ctx) > 0 do
    Kiln.Telemetry.unpack_ctx(ctx)
  end

  defp maybe_unpack_ctx(_), do: :ok
end
