defmodule Kiln.GitHub.CheckPollerTest do
  use Kiln.ObanCase, async: false

  require Logger

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.GitHub.CheckPoller

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)

    on_exit(fn -> Application.delete_env(:kiln, Kiln.GitHub.CheckPoller) end)

    run = RunFactory.insert(:run, state: :verifying)
    stage = StageRunFactory.insert(:stage_run, run_id: run.id)

    sha = String.duplicate("c", 40)

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    fixture_ok =
      "test/fixtures/github/check_runs.json"
      |> File.read!()
      |> Jason.decode!()

    pending = %{
      "head_sha" => sha,
      "check_runs" => [
        %{
          "id" => 1,
          "name" => "required-unit",
          "status" => "in_progress",
          "conclusion" => nil
        }
      ]
    }

    :ok =
      Application.put_env(:kiln, Kiln.GitHub.CheckPoller,
        cli_runner: fn ["api" | _], _opts ->
          n =
            Agent.get_and_update(counter, fn x ->
              {x, x + 1}
            end)

          body = if n == 0, do: pending, else: fixture_ok
          {:ok, Jason.encode!(body)}
        end
      )

    key = "run:#{run.id}:pr:99:sha:#{sha}:gh_check_observe"

    args = %{
      "idempotency_key" => key,
      "run_id" => run.id,
      "stage_id" => stage.id,
      "repo" => "o/r",
      "pr_number" => 99,
      "head_sha" => sha,
      "required_check_names" => ["required-unit", "required-lint"],
      "is_draft" => false
    }

    {:ok, args: args}
  end

  test "gh_check_observe snoozes while checks are pending", %{args: args} do
    assert {:snooze, 15} = perform_job(CheckPoller, args)
  end

  test "gh_check_observe completes when checks pass", %{args: args} do
    assert {:snooze, 15} = perform_job(CheckPoller, args)
    assert {:ok, :completed} = perform_job(CheckPoller, args)
  end
end
