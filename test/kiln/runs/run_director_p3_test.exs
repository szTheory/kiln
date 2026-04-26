defmodule Kiln.Runs.RunDirectorP3Test do
  use Kiln.DataCase, async: false

  alias Kiln.Blockers.BlockedError
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.OperatorReadiness
  alias Kiln.Runs.RunDirector

  setup do
    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:github, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, true)

    for key <- [:anthropic_api_key, :openai_api_key, :google_api_key, :ollama_host] do
      Kiln.Secrets.put(key, nil)
    end

    on_exit(fn ->
      for key <- [:anthropic_api_key, :openai_api_key, :google_api_key, :ollama_host] do
        Kiln.Secrets.put(key, nil)
      end
    end)

    :ok
  end

  test "start_run/1 raises missing_api_key before any LLM call when a required provider is absent" do
    run =
      RunFactory.insert(:run,
        state: :queued,
        model_profile_snapshot: %{"roles" => %{"planner" => "claude-sonnet-4-5"}}
      )

    assert_raise BlockedError, fn ->
      RunDirector.start_run(run.id)
    end
  end

  test "start_run/1 transitions queued -> planning when a required provider is present" do
    :ok = Kiln.Secrets.put(:anthropic_api_key, "test-key")

    run =
      RunFactory.insert(:run,
        state: :queued,
        model_profile_snapshot: %{"roles" => %{"planner" => "claude-sonnet-4-5"}}
      )

    assert {:ok, updated} = RunDirector.start_run(run.id)
    assert updated.state == :planning
  end
end
