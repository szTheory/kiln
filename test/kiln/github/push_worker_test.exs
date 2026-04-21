defmodule Kiln.GitHub.PushWorkerTest do
  use Kiln.ObanCase, async: false

  require Logger

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.GitHub.PushWorker

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)

    ws = Path.join(System.tmp_dir!(), "kiln_push_ws_#{:erlang.unique_integer([:positive])}")
    :ok = File.mkdir_p!(ws)

    on_exit(fn ->
      _ = File.rm_rf(ws)
      Application.delete_env(:kiln, Kiln.GitHub.PushWorker)
    end)

    run = RunFactory.insert(:run, state: :coding)
    stage = StageRunFactory.insert(:stage_run, run_id: run.id)

    sha_a = String.duplicate("a", 40)
    sha_b = String.duplicate("b", 40)

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    runner = fn
      ["ls-remote", _, _], _opts ->
        n =
          Agent.get_and_update(counter, fn x ->
            {x, x + 1}
          end)

        sha = if n == 0, do: sha_a, else: sha_b
        {:ok, "#{sha}\trefs/heads/main\n"}

      ["push", _, _], _opts ->
        {:ok, ""}
    end

    :ok = Application.put_env(:kiln, Kiln.GitHub.PushWorker, git_runner: runner)

    key = "run:#{run.id}:stage:#{stage.id}:git_push"

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

    {:ok, args: args}
  end

  test "git_push completes after CAS + push", %{args: args} do
    assert {:ok, :completed} = perform_job(PushWorker, args)
  end

  test "git_push is idempotent after completion", %{args: args} do
    assert {:ok, :completed} = perform_job(PushWorker, args)
    assert {:ok, :already_done} = perform_job(PushWorker, args)
  end
end
