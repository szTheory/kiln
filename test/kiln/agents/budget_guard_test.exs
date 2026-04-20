defmodule Kiln.Agents.BudgetGuardTest do
  @moduledoc """
  Tests for `Kiln.Agents.BudgetGuard.check!/2` - the 7-step pre-flight
  gate (D-138) that runs BEFORE every LLM call.

  The gate must be strict: no escape hatch, no
  `:skip` option. The test suite asserts this via both a behavioural
  check (breach raises) and a source-level grep.

  Adapter is a hand-rolled stub (`StubAdapter`) rather than the shared
  `Kiln.Agents.AdapterMock`. BudgetGuard's adapter contract is narrow:
  `count_tokens/1` is the only function exercised in the pre-flight
  path.
  """

  defmodule StubAdapter do
    @moduledoc false

    def set_count(pid, count) when is_integer(count) do
      :persistent_term.put({__MODULE__, pid}, count)
    end

    def count_tokens(_prompt) do
      {:ok, :persistent_term.get({__MODULE__, self()}, 1000)}
    end
  end

  use Kiln.DataCase, async: false

  alias Kiln.Agents.BudgetGuard
  alias Kiln.Factory.Run, as: RunFactory

  setup do
    Logger.metadata(correlation_id: Ecto.UUID.generate())
    StubAdapter.set_count(self(), 1000)
    :ok
  end

  describe "check!/2 - pass path" do
    test "returns :ok when estimated cost fits in remaining budget" do
      run = RunFactory.insert(:run, caps_snapshot: %{"max_tokens_usd" => "100.00"})

      StubAdapter.set_count(self(), 1000)

      prompt = %{model: "claude-sonnet-4-5-20250929", max_tokens: 500}

      assert :ok =
               BudgetGuard.check!(prompt,
                 run_id: run.id,
                 stage_id: nil,
                 adapter: StubAdapter
               )
    end

    test "emits budget_check_passed audit event on pass" do
      run = RunFactory.insert(:run, caps_snapshot: %{"max_tokens_usd" => "100.00"})

      StubAdapter.set_count(self(), 1000)

      prompt = %{model: "claude-sonnet-4-5-20250929", max_tokens: 500}

      :ok =
        BudgetGuard.check!(prompt,
          run_id: run.id,
          stage_id: nil,
          adapter: StubAdapter
        )

      import Ecto.Query

      rows =
        Kiln.Repo.all(
          from(e in Kiln.Audit.Event,
            where: e.event_kind == ^:budget_check_passed and e.run_id == ^run.id
          )
        )

      assert length(rows) == 1
      [row] = rows
      assert row.payload["model"] == "claude-sonnet-4-5-20250929"
      assert row.payload["estimated_usd"]
      assert row.payload["remaining_usd"]
    end
  end

  describe "check!/2 - breach path" do
    test "raises BlockedError with reason :budget_exceeded when estimate exceeds remaining" do
      run = RunFactory.insert(:run, caps_snapshot: %{"max_tokens_usd" => "0.01"})

      StubAdapter.set_count(self(), 1_000_000)

      prompt = %{model: "claude-opus-4-5-20250929", max_tokens: 1_000_000}

      assert_raise Kiln.Blockers.BlockedError, fn ->
        BudgetGuard.check!(prompt,
          run_id: run.id,
          stage_id: nil,
          adapter: StubAdapter
        )
      end
    end

    test "emits budget_check_failed audit event BEFORE raising" do
      run = RunFactory.insert(:run, caps_snapshot: %{"max_tokens_usd" => "0.01"})

      StubAdapter.set_count(self(), 1_000_000)

      prompt = %{model: "claude-opus-4-5-20250929", max_tokens: 1_000_000}

      assert_raise Kiln.Blockers.BlockedError, fn ->
        BudgetGuard.check!(prompt,
          run_id: run.id,
          stage_id: nil,
          adapter: StubAdapter
        )
      end

      import Ecto.Query

      rows =
        Kiln.Repo.all(
          from(e in Kiln.Audit.Event,
            where: e.event_kind == ^:budget_check_failed and e.run_id == ^run.id
          )
        )

      assert length(rows) == 1
      [row] = rows
      assert row.payload["model"] == "claude-opus-4-5-20250929"
    end

    test "raises with reason: :budget_exceeded on the BlockedError" do
      run = RunFactory.insert(:run, caps_snapshot: %{"max_tokens_usd" => "0.01"})

      StubAdapter.set_count(self(), 1_000_000)

      prompt = %{model: "claude-opus-4-5-20250929", max_tokens: 1_000_000}

      err =
        try do
          BudgetGuard.check!(prompt,
            run_id: run.id,
            stage_id: nil,
            adapter: StubAdapter
          )

          flunk("expected BlockedError")
        rescue
          e in Kiln.Blockers.BlockedError -> e
        end

      assert err.reason == :budget_exceeded
      assert err.run_id == run.id
      assert is_map(err.context)
    end
  end

  describe "source-level invariant" do
    test "no escape hatch in source (D-138)" do
      source = File.read!("lib/kiln/agents/budget_guard.ex")
      refute source =~ "KILN_BUDGET_OVERRIDE"
      refute source =~ "BUDGET_OVERRIDE"
    end

    test "no :skip option handled in source (D-138)" do
      source = File.read!("lib/kiln/agents/budget_guard.ex")
      refute source =~ ~r/\b:skip\b/
    end
  end
end
