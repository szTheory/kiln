defmodule Kiln.Runs.RunDirectorFairnessTest do
  @moduledoc """
  Asserts the **`Runs.list_active/0` → `FairRoundRobin.order/2`** expression
  used in **`RunDirector`** ordering (PARA-01 admission slice).

  Full `DynamicSupervisor.start_child/2` spawn ordering is not asserted here;
  see **`FairRoundRobinTest`** for pure ordering invariants.
  """

  use Kiln.DataCase, async: false

  import Ecto.Query
  import Kiln.RehydrationCase

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Repo
  alias Kiln.Runs
  alias Kiln.Runs.{FairRoundRobin, Run, RunDirector}
  alias Kiln.Workflows

  setup do
    _ = System.put_env("KILN_SKIP_OPERATOR_READINESS", "1")

    on_exit(fn ->
      System.delete_env("KILN_SKIP_OPERATOR_READINESS")
    end)

    :ok
  end

  test "parity with director ordering: FairRoundRobin over list_active" do
    {:ok, graph} = Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

    r1 =
      RunFactory.insert(:run,
        workflow_id: graph.id,
        workflow_version: graph.version,
        workflow_checksum: graph.checksum,
        state: :queued
      )

    r2 =
      RunFactory.insert(:run,
        workflow_id: graph.id,
        workflow_version: graph.version,
        workflow_checksum: graph.checksum,
        state: :queued
      )

    r3 =
      RunFactory.insert(:run,
        workflow_id: graph.id,
        workflow_version: graph.version,
        workflow_checksum: graph.checksum,
        state: :queued
      )

    t1 = ~U[2022-01-01 00:00:00.000000Z]
    t2 = ~U[2022-01-02 00:00:00.000000Z]
    t3 = ~U[2022-01-03 00:00:00.000000Z]

    _ =
      Repo.update_all(from(r in Run, where: r.id == ^r1.id),
        set: [inserted_at: t1, updated_at: t1]
      )

    _ =
      Repo.update_all(from(r in Run, where: r.id == ^r2.id),
        set: [inserted_at: t2, updated_at: t2]
      )

    _ =
      Repo.update_all(from(r in Run, where: r.id == ^r3.id),
        set: [inserted_at: t3, updated_at: t3]
      )

    active = Runs.list_active()
    ordered_once = FairRoundRobin.order(active, nil)
    assert hd(ordered_once).id == r1.id

    ordered = FairRoundRobin.order(active, r1.id)
    assert hd(ordered).id == r2.id

    assert Process.whereis(RunDirector) != nil
    _ = reset_run_director_for_test()
  end
end
