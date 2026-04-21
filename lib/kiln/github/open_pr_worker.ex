defmodule Kiln.GitHub.OpenPRWorker do
  @moduledoc """
  Oban worker for `gh_pr_create` (`external_operations`, GIT-02).

  Idempotency key: `"run:" <> run_id <> ":stage:" <> stage_id <> ":gh_pr_create"`.

  Auth failures (`:gh_auth_expired`, `:gh_permissions_insufficient`) return
  `{:cancel, reason}` so Oban does not spin — typed block producers consume
  these in Plan 04.
  """

  use Kiln.Oban.BaseWorker, queue: :github

  alias Kiln.GitHub.Cli

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, meta: meta}) do
    _ = maybe_unpack_ctx(meta)

    with {:ok, parsed} <- parse_args(args),
         :ok <- assert_expected_key(parsed.idempotency_key, parsed.run_id, parsed.stage_id) do
      key = parsed.idempotency_key

      case fetch_or_record_intent(key, %{
             op_kind: "gh_pr_create",
             intent_payload: parsed.intent_payload,
             run_id: parsed.run_id,
             stage_id: parsed.stage_id
           }) do
        {:found_existing, %{state: :completed}} ->
          {:ok, :duplicate_suppressed}

        {:error, _} = err ->
          err

        {_ins, op} ->
          case Cli.create_pr(parsed.pr_attrs, runner: cli_runner()) do
            {:ok, json} ->
              pr_number = Map.fetch!(json, "number")

              case complete_op(op, %{
                     "pr_number" => pr_number,
                     "pr_url" => Map.get(json, "url"),
                     "is_draft" => Map.get(json, "isDraft", false)
                   }) do
                {:ok, _} -> {:ok, :completed}
                {:error, reason} -> {:error, reason}
              end

            {:error, %{} = raw} ->
              _ = fail_op(op, %{"reason" => "gh_cli", "detail" => inspect(raw)})
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
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_args(args) do
    with {:ok, idempotency_key} <- fetch_str(args, "idempotency_key"),
         {:ok, run_id} <- cast_uuid(args, "run_id"),
         {:ok, stage_id} <- cast_uuid(args, "stage_id"),
         {:ok, title} <- fetch_str(args, "title"),
         {:ok, body} <- fetch_str(args, "body"),
         {:ok, base} <- fetch_str(args, "base"),
         {:ok, head} <- fetch_str(args, "head"),
         {:ok, draft} <- fetch_bool(args, "draft"),
         {:ok, reviewers} <- fetch_reviewers(args) do
      pr_attrs = %{
        "title" => title,
        "body" => body,
        "base" => base,
        "head" => head,
        "draft" => draft,
        "reviewers" => reviewers
      }

      {:ok,
       %{
         idempotency_key: idempotency_key,
         run_id: run_id,
         stage_id: stage_id,
         intent_payload: Map.merge(pr_attrs, %{"frozen" => true}),
         pr_attrs: pr_attrs
       }}
    end
  end

  defp fetch_bool(m, k) do
    case Map.get(m, k) do
      b when is_boolean(b) -> {:ok, b}
      _ -> {:error, {:bad_bool, k}}
    end
  end

  defp fetch_reviewers(args) do
    case Map.get(args, "reviewers", []) do
      list when is_list(list) -> {:ok, list}
      _ -> {:error, {:bad_reviewers, "reviewers"}}
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

  defp assert_expected_key(key, run_id, stage_id) do
    want = "run:#{run_id}:stage:#{stage_id}:gh_pr_create"
    if key == want, do: :ok, else: {:error, {:bad_idempotency_key, want, key}}
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
