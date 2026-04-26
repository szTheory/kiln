defmodule Kiln.Attach.DeliveryTest do
  use Kiln.ObanCase, async: false

  import Ecto.Changeset

  alias Kiln.Attach
  alias Kiln.Attach.AttachedRepo
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.Repo
  alias Kiln.Runs
  alias Kiln.Specs
  alias Kiln.GitHub.{OpenPRWorker, PushWorker}

  setup do
    workspace_path = make_git_repo!("kiln_attach_delivery")

    attached_repo =
      %AttachedRepo{}
      |> AttachedRepo.changeset(%{
        source_kind: :local_path,
        repo_provider: :github,
        repo_host: "github.com",
        repo_owner: "owner",
        repo_name: "Repo Name With Spaces + Extra Symbols!!!",
        repo_slug: "owner/repo-name",
        canonical_input: workspace_path,
        canonical_repo_root: workspace_path,
        source_fingerprint: "local_path:#{workspace_path}",
        workspace_key: "repo-name-key",
        workspace_path: workspace_path,
        remote_url: "https://github.com/owner/repo-name.git",
        clone_url: "https://github.com/owner/repo-name.git",
        default_branch: "main",
        base_branch: "main"
      })
      |> Repo.insert!()

    {:ok, spec} = Specs.create_spec(%{title: "Attached request"})

    {:ok, revision} =
      Specs.create_revision(spec, %{
        body: "# Attach request\n\nScope this draft PR handoff.\n",
        attached_repo_id: attached_repo.id,
        request_kind: :feature,
        change_summary: "Render compact PR handoff from durable attached request",
        acceptance_criteria: [
          "Reviewer sees scoped summary and acceptance criteria.",
          "Verification section cites the owning proof command."
        ],
        out_of_scope: ["Do not widen into repo-wide proof gates."]
      })

    run =
      RunFactory.insert(:run,
        state: :coding,
        attached_repo_id: attached_repo.id,
        spec_id: spec.id,
        spec_revision_id: revision.id
      )

    stage = StageRunFactory.insert(:stage_run, run_id: run.id)

    {:ok, attached_repo: attached_repo, run: run, stage: stage, workspace_path: workspace_path}
  end

  test "freezes one deterministic branch and reuses it on retry", %{
    attached_repo: attached_repo,
    run: run,
    stage: stage,
    workspace_path: workspace_path
  } do
    parent = self()

    runner = fn argv, opts ->
      send(parent, {:git_call, argv})
      git_runner(argv, opts)
    end

    assert {:ok, first} =
             Attach.prepare_delivery(run, attached_repo.id, stage.id, git_runner: runner)

    branch = first.push_args["refspec"] |> String.replace_prefix("refs/heads/", "")

    assert branch =~ ~r/^kiln\/attach\/owner-repo-name-r[0-9a-f]{8}$/
    assert_receive {:git_call, ["check-ref-format", "--branch", ^branch]}

    mutated =
      attached_repo
      |> change(%{
        repo_slug: "wrong/repo",
        workspace_path: Path.join(workspace_path, "different"),
        base_branch: "develop"
      })
      |> Repo.update!()

    assert {:ok, second} =
             Attach.prepare_delivery(run.id, mutated.id, stage.id, git_runner: runner)

    assert second.push_args["refspec"] == first.push_args["refspec"]
    assert second.push_args["workspace_dir"] == first.push_args["workspace_dir"]
    assert second.pr_args["base"] == first.pr_args["base"]
    assert second.pr_args["title"] == first.pr_args["title"]

    stored = Runs.get!(run.id).github_delivery_snapshot
    assert stored["attach"]["branch"] == branch
    assert stored["attach"]["workspace_path"] == workspace_path
    assert stored["attach"]["base_branch"] == "main"
    assert stored["pr"]["head"] == branch
    assert stored["pr"]["draft"] == true

    assert stored["pr"]["title"] =~
             "Feature: Render compact PR handoff from durable attached request"
  end

  test "enqueues frozen push and draft PR jobs from persisted attached repo facts", %{
    attached_repo: attached_repo,
    run: run,
    stage: stage,
    workspace_path: workspace_path
  } do
    assert {:ok, prepared} = Attach.enqueue_delivery(run.id, attached_repo.id, stage.id)

    assert_enqueued(
      worker: PushWorker,
      args: %{
        "run_id" => run.id,
        "stage_id" => stage.id,
        "workspace_dir" => workspace_path,
        "remote" => "origin",
        "expected_remote_sha" => String.duplicate("0", 40)
      }
    )

    assert_enqueued(
      worker: OpenPRWorker,
      args: %{
        "run_id" => run.id,
        "stage_id" => stage.id,
        "base" => "main",
        "head" => prepared.pr_args["head"],
        "draft" => true,
        "reviewers" => []
      }
    )

    body = prepared.pr_args["body"]

    assert body =~ "## Summary"
    assert body =~ "Feature: Render compact PR handoff from durable attached request"
    assert body =~ "## Acceptance criteria"
    assert body =~ "- Reviewer sees scoped summary and acceptance criteria."
    assert body =~ "## Out of scope"
    assert body =~ "- Do not widen into repo-wide proof gates."
    assert body =~ "## Verification"
    assert body =~ "MIX_ENV=test mix kiln.attach.prove"
    assert body =~ "test/kiln/attach/continuity_test.exs"
    assert body =~ "## Branch context"
    assert body =~ "- Branch: `#{prepared.pr_args["head"]}`"
    assert body =~ "- Base branch: `main`"
    assert body =~ "kiln-run: #{run.id}"
    assert length(Regex.scan(~r/kiln-run:/, body)) == 1
    refute body =~ "Attached repo:"
    refute body =~ "attached_repo_id"
  end

  test "omits out of scope section when no bounded exclusions are stored", %{
    attached_repo: attached_repo
  } do
    {:ok, spec} = Specs.create_spec(%{title: "Attached request without exclusions"})

    {:ok, revision} =
      Specs.create_revision(spec, %{
        body: "# Attach request\n\nNo exclusions.\n",
        attached_repo_id: attached_repo.id,
        request_kind: :bugfix,
        change_summary: "Narrow PR handoff without out of scope items",
        acceptance_criteria: ["Reviewer sees a compact bugfix handoff."],
        out_of_scope: []
      })

    run =
      RunFactory.insert(:run,
        state: :coding,
        attached_repo_id: attached_repo.id,
        spec_id: spec.id,
        spec_revision_id: revision.id
      )

    stage = StageRunFactory.insert(:stage_run, run_id: run.id)

    assert {:ok, prepared} = Attach.prepare_delivery(run.id, attached_repo.id, stage.id)
    refute prepared.pr_args["body"] =~ "## Out of scope"
  end

  defp make_git_repo!(name) do
    repo_root =
      Path.join(
        System.tmp_dir!(),
        "#{name}_#{System.os_time(:microsecond)}_#{System.unique_integer([:positive, :monotonic])}"
      )

    File.mkdir_p!(repo_root)

    {_, 0} = System.cmd("git", ["init", "--quiet", "--initial-branch=main", repo_root])
    File.write!(Path.join(repo_root, "README.md"), "# #{name}\n")
    {_, 0} = System.cmd("git", ["-C", repo_root, "add", "README.md"])

    {_, 0} =
      System.cmd("git", [
        "-C",
        repo_root,
        "-c",
        "user.name=Kiln Test",
        "-c",
        "user.email=test@example.com",
        "commit",
        "--quiet",
        "-m",
        "initial"
      ])

    {_, 0} =
      System.cmd("git", [
        "-C",
        repo_root,
        "remote",
        "add",
        "origin",
        "https://github.com/owner/repo-name.git"
      ])

    repo_root
  end

  defp git_runner(argv, opts) do
    case Keyword.get(opts, :cd) do
      nil ->
        {output, status} = System.cmd("git", argv, stderr_to_stdout: true)
        git_result(output, status)

      cd ->
        {output, status} = System.cmd("git", argv, cd: cd, stderr_to_stdout: true)
        git_result(output, status)
    end
  end

  defp git_result(output, 0), do: {:ok, String.trim(output)}
  defp git_result(output, status), do: {:error, %{exit_status: status, stderr: output}}
end
