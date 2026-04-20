defmodule Kiln.WorkUnitClaimRaceTest do
  @moduledoc """
  Claim arbitration is enforced with `FOR UPDATE SKIP LOCKED` plus an
  optimistic `updated_at` guard on `claim_next_ready/2`.

  Full multi-connection race proofs live better outside the SQL sandbox;
  this module pins the single-connection contract the app relies on.
  """

  use Kiln.DataCase, async: false

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.WorkUnits

  test "only one claim succeeds for a single ready planner unit" do
    run = RunFactory.insert(:run)
    assert {:ok, _} = WorkUnits.seed_initial_planner_unit(run.id)

    assert {:ok, _} = WorkUnits.claim_next_ready(run.id, :planner)
    assert {:error, :none_ready} = WorkUnits.claim_next_ready(run.id, :planner)
  end
end
