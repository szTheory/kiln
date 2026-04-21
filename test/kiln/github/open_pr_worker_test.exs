defmodule Kiln.GitHub.OpenPRWorkerTest do
  use Kiln.ObanCase, async: false

  require Logger

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.GitHub.OpenPRWorker

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)

    on_exit(fn -> Application.delete_env(:kiln, Kiln.GitHub.OpenPRWorker) end)

    run = RunFactory.insert(:run, state: :coding)
    stage = StageRunFactory.insert(:stage_run, run_id: run.id)

    json =
      ~s({"number":7,"url":"https://github.com/o/r/pull/7","headRefName":"f","baseRefName":"main","isDraft":true})

    :ok =
      Application.put_env(:kiln, Kiln.GitHub.OpenPRWorker,
        cli_runner: fn argv, _opts ->
          assert argv == [
                   "pr",
                   "create",
                   "--title",
                   "t",
                   "--base",
                   "main",
                   "--head",
                   "f",
                   "--draft",
                   "--body",
                   "b",
                   "--json",
                   "number,url,headRefName,baseRefName,isDraft"
                 ]

          {:ok, json}
        end
      )

    key = "run:#{run.id}:stage:#{stage.id}:gh_pr_create"

    args = %{
      "idempotency_key" => key,
      "run_id" => run.id,
      "stage_id" => stage.id,
      "title" => "t",
      "body" => "b",
      "base" => "main",
      "head" => "f",
      "draft" => true,
      "reviewers" => []
    }

    {:ok, args: args}
  end

  test "gh_pr_create completes with pr_number in result", %{args: args} do
    assert {:ok, :completed} = perform_job(OpenPRWorker, args)
  end

  test "duplicate job returns duplicate_suppressed", %{args: args} do
    assert {:ok, :completed} = perform_job(OpenPRWorker, args)
    assert {:ok, :duplicate_suppressed} = perform_job(OpenPRWorker, args)
  end
end
