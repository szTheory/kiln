defmodule Kiln.Oban.BaseWorkerTest do
  @moduledoc """
  Mechanical proof of behavior 14 from 01-VALIDATION.md plus the two
  D-44 invariants that make every Kiln Oban worker safe by default:

    * Behavior 14 — inserting two jobs with the same `idempotency_key`
      while the first is still in `[:available, :scheduled, :executing]`
      collapses into one `oban_jobs` row. The UNIQUE here is
      Oban's insert-time `args -> 'idempotency_key'` dedupe (D-44), NOT
      the `external_operations` row-level unique (which is tested in
      `Kiln.ExternalOperationsTest`).
    * `max_attempts` defaults to 3 when the worker does not override,
      overriding Oban's default of 20 (PITFALLS P9).
    * Explicit override (`use Kiln.Oban.BaseWorker, max_attempts: 5`)
      wins — the BaseWorker's defaults are non-clobbering.
    * Helper delegation — `fetch_or_record_intent/2`, `complete_op/2`,
      `fail_op/2` forward to `Kiln.ExternalOperations`.

  `async: false` because Oban's insert path writes to the shared
  `oban_jobs` table and `use Oban.Testing` attaches to a singleton
  repo. DataCase wraps every test in an Ecto sandbox txn so inserted
  jobs are rolled back automatically.
  """

  use Kiln.DataCase, async: false
  use Oban.Testing, repo: Kiln.Repo

  require Logger

  defmodule TestWorker do
    @moduledoc false

    use Kiln.Oban.BaseWorker, queue: :default

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"idempotency_key" => key} = args}) do
      case fetch_or_record_intent(key, %{
             op_kind: "test_worker",
             intent_payload: args
           }) do
        {:found_existing, %{state: :completed} = op} ->
          {:ok, op}

        {_status, op} ->
          {:ok, _completed} = complete_op(op, %{"tested" => true})
          :ok
      end
    end
  end

  defmodule OverrideWorker do
    @moduledoc false

    # Explicit max_attempts: 5 must override the BaseWorker default of 3.
    use Kiln.Oban.BaseWorker, queue: :default, max_attempts: 5

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  setup do
    Logger.metadata(correlation_id: Ecto.UUID.generate())
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)
    :ok
  end

  describe "safe defaults (D-44, PITFALLS P9)" do
    test "max_attempts defaults to 3 when not overridden" do
      opts = TestWorker.__opts__()
      assert Keyword.fetch!(opts, :max_attempts) == 3
    end

    test "explicit max_attempts: 5 overrides the BaseWorker default" do
      opts = OverrideWorker.__opts__()
      assert Keyword.fetch!(opts, :max_attempts) == 5
    end

    test "unique config defaults to idempotency_key + period :infinity + (available|scheduled|executing)" do
      opts = TestWorker.__opts__()
      unique = Keyword.fetch!(opts, :unique)

      assert Keyword.fetch!(unique, :keys) == [:idempotency_key]
      assert Keyword.fetch!(unique, :period) == :infinity
      assert Keyword.fetch!(unique, :states) == [:available, :scheduled, :executing]
    end
  end

  describe "unique-key dedupe on insert (behavior 14)" do
    test "enqueueing the same idempotency_key twice inserts only one oban_jobs row" do
      key = "run_1:stage_1:test_op"

      assert {:ok, job1} =
               %{idempotency_key: key}
               |> TestWorker.new()
               |> Oban.insert()

      assert {:ok, job2} =
               %{idempotency_key: key}
               |> TestWorker.new()
               |> Oban.insert()

      # Second insert returns the first job's row (not a new one)
      assert job1.id == job2.id

      count =
        Repo.one(
          from(j in "oban_jobs",
            where: j.worker == "Kiln.Oban.BaseWorkerTest.TestWorker",
            where: fragment("? ->> 'idempotency_key'", j.args) == ^key,
            select: count(j.id)
          )
        )

      assert count == 1
    end

    test "different idempotency_keys insert as separate jobs" do
      assert {:ok, j1} =
               %{idempotency_key: "run_2:stage_1:op_a"}
               |> TestWorker.new()
               |> Oban.insert()

      assert {:ok, j2} =
               %{idempotency_key: "run_2:stage_1:op_b"}
               |> TestWorker.new()
               |> Oban.insert()

      assert j1.id != j2.id
    end
  end

  describe "helper delegation" do
    test "fetch_or_record_intent/2 forwards to Kiln.ExternalOperations" do
      assert {:inserted_new, op} =
               TestWorker.fetch_or_record_intent("run_x:stage_x:delegate_intent", %{
                 op_kind: "test_worker",
                 intent_payload: %{"from" => "basework_test"}
               })

      assert op.op_kind == "test_worker"
      assert op.state == :intent_recorded
    end

    test "complete_op/2 forwards to Kiln.ExternalOperations" do
      {:inserted_new, op} =
        TestWorker.fetch_or_record_intent("run_x:stage_x:delegate_complete", %{
          op_kind: "test_worker",
          intent_payload: %{}
        })

      assert {:ok, completed} = TestWorker.complete_op(op, %{"ok" => true})
      assert completed.state == :completed
    end

    test "fail_op/2 forwards to Kiln.ExternalOperations" do
      {:inserted_new, op} =
        TestWorker.fetch_or_record_intent("run_x:stage_x:delegate_fail", %{
          op_kind: "test_worker",
          intent_payload: %{}
        })

      assert {:ok, failed} = TestWorker.fail_op(op, %{"type" => "test"})
      assert failed.state == :failed
    end
  end
end
