defmodule Kiln.GitHub.PushWorker do
  @moduledoc """
  Oban worker for durable `git_push` via `external_operations` (GIT-01).

  ## Args

  Required string keys:

    * `"idempotency_key"` — must equal `"run:" <> run_id <> ":stage:" <> stage_id <> ":git_push"`
    * `"run_id"`, `"stage_id"` — UUID strings
    * `"workspace_dir"` — absolute path to git repo root (validated when
      `:github_workspace_root` is configured — see `config/config.exs`)
    * `"remote"` — e.g. `"origin"`
    * `"refspec"` — e.g. `"refs/heads/main"`
    * `"expected_remote_sha"`, `"local_commit_sha"` — CAS fields (D-G16)

  ## Retry vs cancel

  * `:git_push_rejected` (unknown / generic transport) → `{:error, _}` so
    Oban retries a bounded number of times.
  * `:git_non_fast_forward`, `:git_remote_advanced` → `fail_op/2` then
    `{:cancel, atom}` — semantic terminal; no Oban spin.
  """

  use Kiln.Oban.BaseWorker, queue: :github

  alias Kiln.Git

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, meta: meta}) do
    _ = maybe_unpack_ctx(meta)

    with {:ok, parsed} <- parse_args(args),
         :ok <- validate_workspace_dir(parsed.workspace_dir) do
      do_perform(parsed)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_perform(parsed) do
    runner = git_runner()

    case fetch_or_record_intent(parsed.idempotency_key, %{
           op_kind: "git_push",
           intent_payload: Map.take(parsed.raw_args, cas_fields()),
           run_id: parsed.run_id,
           stage_id: parsed.stage_id
         }) do
      {:found_existing, %{state: :completed}} ->
        {:ok, :already_done}

      {:error, _} = err ->
        err

      {_ins, op} ->
        case Git.ls_remote_tip(parsed.remote, parsed.ref, runner) do
          {:ok, tip} ->
            cond do
              tip == parsed.local_sha ->
                complete_ok(op, %{"result" => "noop_already_on_remote", "remote_sha" => tip})

              tip != parsed.expected_sha ->
                reason = :git_remote_advanced

                _ =
                  fail_op(op, %{
                    "reason" => Atom.to_string(reason),
                    "tip" => tip,
                    "expected" => parsed.expected_sha
                  })

                {:cancel, reason}

              true ->
                run_push(op, parsed, runner)
            end

          {:error, :ls_remote_empty} ->
            if parsed.expected_sha == Git.missing_remote_sha() do
              run_push(op, parsed, runner)
            else
              _ =
                fail_op(op, %{
                  "reason" => "ls_remote_failed",
                  "detail" => inspect(:ls_remote_empty)
                })

              {:error, {:ls_remote, :ls_remote_empty}}
            end

          {:error, ls_reason} ->
            _ = fail_op(op, %{"reason" => "ls_remote_failed", "detail" => inspect(ls_reason)})
            {:error, {:ls_remote, ls_reason}}
        end
    end
  end

  defp run_push(op, parsed, runner) do
    argv = ["push", parsed.remote, parsed.refspec]

    case Git.run_push(argv, runner: runner, cd: parsed.workspace_dir) do
      {:ok, out} ->
        case Git.ls_remote_tip(parsed.remote, parsed.ref, runner) do
          {:ok, tip} ->
            complete_ok(op, %{
              "result" => "pushed",
              "remote_sha" => tip,
              "stdout" => String.slice(out, 0, 500)
            })

          {:error, _} = err ->
            _ = fail_op(op, %{"reason" => "post_push_ls_failed", "detail" => inspect(err)})
            {:error, err}
        end

      {:error, %{exit_status: code, stderr: err}} ->
        class = Git.classify_push_failure(code, err)

        case class do
          :git_push_rejected ->
            _ =
              fail_op(op, %{
                "reason" => "git_push",
                "class" => "git_push_rejected",
                "stderr" => err
              })

            {:error, :git_push_rejected}

          other ->
            _ = fail_op(op, %{"reason" => Atom.to_string(other), "stderr" => err})
            {:cancel, other}
        end
    end
  end

  defp complete_ok(op, payload) do
    case complete_op(op, payload) do
      {:ok, _} -> {:ok, :completed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cas_fields,
    do: ["expected_remote_sha", "local_commit_sha", "refspec", "remote", "workspace_dir"]

  defp parse_args(args) do
    with {:ok, idempotency_key} <- fetch_str(args, "idempotency_key"),
         {:ok, run_id} <- cast_uuid(args, "run_id"),
         {:ok, stage_id} <- cast_uuid(args, "stage_id"),
         {:ok, workspace_dir} <- fetch_str(args, "workspace_dir"),
         {:ok, remote} <- fetch_str(args, "remote"),
         {:ok, refspec} <- fetch_str(args, "refspec"),
         {:ok, expected_sha} <- fetch_str(args, "expected_remote_sha"),
         {:ok, local_sha} <- fetch_str(args, "local_commit_sha"),
         :ok <- assert_expected_key(idempotency_key, run_id, stage_id) do
      ref = ref_from_refspec(refspec)

      {:ok,
       %{
         raw_args: args,
         idempotency_key: idempotency_key,
         run_id: run_id,
         stage_id: stage_id,
         workspace_dir: workspace_dir,
         remote: remote,
         refspec: refspec,
         ref: ref,
         expected_sha: expected_sha,
         local_sha: local_sha
       }}
    end
  end

  defp assert_expected_key(key, run_id, stage_id) do
    want = "run:#{run_id}:stage:#{stage_id}:git_push"

    if key == want do
      :ok
    else
      {:error, {:bad_idempotency_key, want, key}}
    end
  end

  defp ref_from_refspec("refs/heads/" <> _ = r), do: r
  defp ref_from_refspec("refs/tags/" <> _ = r), do: r
  defp ref_from_refspec(other), do: other

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

  defp validate_workspace_dir(dir) do
    case Application.get_env(:kiln, :github_workspace_root) do
      nil ->
        :ok

      root ->
        expanded = Path.expand(dir)
        root_exp = Path.expand(root)

        if String.starts_with?(expanded, root_exp) do
          :ok
        else
          {:error, {:workspace_dir_not_allowed, expanded, root_exp}}
        end
    end
  end

  defp git_runner do
    Application.get_env(:kiln, __MODULE__, [])
    |> Keyword.get(:git_runner, Kiln.Git.default_runner())
  end

  defp maybe_unpack_ctx(%{"kiln_ctx" => ctx}) when is_map(ctx) and map_size(ctx) > 0 do
    Kiln.Telemetry.unpack_ctx(ctx)
  end

  defp maybe_unpack_ctx(_), do: :ok
end
