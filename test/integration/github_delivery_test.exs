defmodule Kiln.Integration.GithubDeliveryTest do
  @moduledoc false

  use Kiln.ObanCase, async: false

  import Ecto.Query

  require Logger

  alias Kiln.{ExternalOperations.Operation, Repo}
  alias Kiln.Attach
  alias Kiln.Attach.AttachedRepo
  alias Kiln.Audit.Event
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.GitHub.{OpenPRWorker, PushWorker}
  alias Kiln.Specs

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)

    ws = Path.join(System.tmp_dir!(), "kiln_int_push_#{:erlang.unique_integer([:positive])}")
    :ok = File.mkdir_p!(ws)

    on_exit(fn ->
      _ = File.rm_rf(ws)
      Application.delete_env(:kiln, Kiln.GitHub.PushWorker)
      Application.delete_env(:kiln, Kiln.GitHub.OpenPRWorker)
    end)

    run = RunFactory.insert(:run, state: :verifying)
    stage = StageRunFactory.insert(:stage_run, run_id: run.id)

    sha_a = String.duplicate("a", 40)
    sha_b = String.duplicate("b", 40)

    key = "run:#{run.id}:stage:#{stage.id}:git_push"

    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {:ok, _} =
      %Operation{}
      |> Operation.changeset(%{
        op_kind: "git_push",
        idempotency_key: key,
        state: :completed,
        intent_payload: %{},
        result_payload: %{"result" => "precompleted"},
        run_id: run.id,
        stage_id: stage.id,
        intent_recorded_at: now,
        completed_at: now
      })
      |> Repo.insert()

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    runner = fn
      ["ls-remote", _, _], _opts ->
        _ =
          Agent.get_and_update(counter, fn x ->
            {x, x + 1}
          end)

        sha = sha_b
        {:ok, "#{sha}\trefs/heads/main\n"}

      ["push", _, _], _opts ->
        {:ok, ""}
    end

    :ok = Application.put_env(:kiln, Kiln.GitHub.PushWorker, git_runner: runner)

    args = %{
      "idempotency_key" => key,
      "run_id" => run.id,
      "stage_id" => stage.id,
      "workspace_dir" => ws,
      "remote" => "origin",
      "refspec" => "refs/heads/main",
      "expected_remote_sha" => sha_a,
      "local_commit_sha" => sha_b
    }

    {:ok, run: run, args: args}
  end

  test "PushWorker replay does not append duplicate external_op_completed audits", %{
    run: run,
    args: args
  } do
    before =
      Repo.aggregate(
        from(e in Event,
          where: e.run_id == ^run.id and e.event_kind == :external_op_completed
        ),
        :count,
        :id
      )

    assert {:ok, :already_done} = perform_job(PushWorker, args)
    assert {:ok, :already_done} = perform_job(PushWorker, args)

    after_count =
      Repo.aggregate(
        from(e in Event,
          where: e.run_id == ^run.id and e.event_kind == :external_op_completed
        ),
        :count,
        :id
      )

    assert after_count == before
  end

  test "attached repo happy path freezes branch then performs push and draft PR delivery" do
    workspace_path =
      Path.join(System.tmp_dir!(), "kiln_delivery_repo_#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_path)

    attached_repo =
      %AttachedRepo{}
      |> AttachedRepo.changeset(%{
        source_kind: :local_path,
        repo_provider: :github,
        repo_host: "github.com",
        repo_owner: "owner",
        repo_name: "delivery-repo",
        repo_slug: "owner/delivery-repo",
        canonical_input: workspace_path,
        canonical_repo_root: workspace_path,
        source_fingerprint: "local_path:#{workspace_path}",
        workspace_key: "delivery-repo",
        workspace_path: workspace_path,
        remote_url: "https://github.com/owner/delivery-repo.git",
        clone_url: "https://github.com/owner/delivery-repo.git",
        default_branch: "main",
        base_branch: "main"
      })
      |> Repo.insert!()

    {:ok, spec} = Specs.create_spec(%{title: "Attached request integration proof"})

    {:ok, revision} =
      Specs.create_revision(spec, %{
        body: "# Attach request\n\nIntegration coverage.\n",
        attached_repo_id: attached_repo.id,
        request_kind: :feature,
        change_summary: "Synchronize draft PR verification citations with owning proof layers",
        acceptance_criteria: [
          "Draft PR body cites exact delegated proof layers.",
          "Snapshot replay preserves identical PR body."
        ],
        out_of_scope: ["Do not add repository-wide proof commands."]
      })

    run =
      RunFactory.insert(:run,
        state: :verifying,
        attached_repo_id: attached_repo.id,
        spec_id: spec.id,
        spec_revision_id: revision.id
      )

    stage = StageRunFactory.insert(:stage_run, run_id: run.id)

    sha_local = String.duplicate("b", 40)

    Application.put_env(:kiln, Kiln.GitHub.PushWorker,
      git_runner: fn
        ["ls-remote", _, "refs/heads/" <> _], _opts ->
          {:ok, "#{sha_local}\tignored\n"}

        ["push", _, "refs/heads/" <> _], _opts ->
          {:ok, ""}
      end
    )

    Application.put_env(:kiln, Kiln.GitHub.OpenPRWorker,
      cli_runner: fn argv, _opts ->
        assert "--draft" in argv
        assert "kiln/attach/owner-delivery-repo-r" <> _ = Enum.at(argv, 7)

        {:ok,
         ~s({"number":9,"url":"https://github.com/owner/delivery-repo/pull/9","headRefName":"f","baseRefName":"main","isDraft":true})}
      end
    )

    git_runner = fn
      ["check-ref-format", "--branch", _branch], _opts -> {:ok, ""}
      ["branch", "--list", _branch], _opts -> {:ok, ""}
      ["switch", "-c", _branch], _opts -> {:ok, ""}
      ["rev-parse", "HEAD"], _opts -> {:ok, sha_local}
    end

    assert {:ok, prepared} =
             Attach.enqueue_delivery(run.id, attached_repo.id, stage.id, git_runner: git_runner)

    assert {:ok, :completed} = perform_job(PushWorker, prepared.push_args)
    assert {:ok, :completed} = perform_job(OpenPRWorker, prepared.pr_args)

    stored = Repo.get!(Kiln.Runs.Run, run.id).github_delivery_snapshot
    assert stored["attach"]["branch"] == prepared.pr_args["head"]
    assert stored["pr"]["head"] == prepared.pr_args["head"]
    assert stored["pr"]["draft"] == true
    assert stored["pr"]["title"] =~ "Feature: Synchronize draft PR verification citations"
    assert stored["pr"]["body"] == prepared.pr_args["body"]
    assert stored["pr"]["body"] =~ "## Summary"
    assert stored["pr"]["body"] =~ "## Acceptance criteria"
    assert stored["pr"]["body"] =~ "## Verification"
    assert stored["pr"]["body"] =~ "MIX_ENV=test mix kiln.attach.prove"
    assert stored["pr"]["body"] =~ "test/integration/github_delivery_test.exs"
    assert stored["pr"]["body"] =~ "test/kiln/attach/delivery_test.exs"
    assert stored["pr"]["body"] =~ "test/kiln/attach/continuity_test.exs"
    assert stored["pr"]["body"] =~ "test/kiln/attach/safety_gate_test.exs"
    assert stored["pr"]["body"] =~ "test/kiln/attach/brownfield_preflight_test.exs"
    assert stored["pr"]["body"] =~ "test/kiln_web/live/attach_entry_live_test.exs"
    assert stored["pr"]["body"] =~ "## Branch context"
    refute stored["pr"]["body"] =~ "Attached repo:"
    refute stored["pr"]["body"] =~ "attached_repo_id"
  end
end
