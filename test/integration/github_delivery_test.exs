defmodule Kiln.Integration.GithubDeliveryTest do
  @moduledoc false

  use Kiln.ObanCase, async: false

  import Ecto.Query

  require Logger

  alias Kiln.{ExternalOperations.Operation, Repo}
  alias Kiln.Audit.Event
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.GitHub.PushWorker

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)

    ws = Path.join(System.tmp_dir!(), "kiln_int_push_#{:erlang.unique_integer([:positive])}")
    :ok = File.mkdir_p!(ws)

    on_exit(fn ->
      _ = File.rm_rf(ws)
      Application.delete_env(:kiln, Kiln.GitHub.PushWorker)
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
end
