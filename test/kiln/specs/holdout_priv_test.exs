defmodule Kiln.Specs.HoldoutPrivTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Ecto.Query
  import Kiln.AuditLedgerCase, only: [with_role: 2]

  alias Ecto.Adapters.SQL.Sandbox
  alias Kiln.Repo
  alias Kiln.Specs
  alias Kiln.Specs.HoldoutScenario

  setup tags do
    owner = Sandbox.start_owner!(Kiln.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(owner) end)
    :ok
  end

  test "kiln_app role cannot SELECT holdout_scenarios (42501)" do
    {:ok, spec} = Specs.create_spec(%{title: "priv"})

    assert {:ok, _} =
             %HoldoutScenario{}
             |> HoldoutScenario.changeset(%{
               spec_id: spec.id,
               label: "h1",
               body: "body"
             })
             |> Repo.insert()

    assert_raise Postgrex.Error, fn ->
      with_role("kiln_app", fn ->
        Repo.all(from(h in HoldoutScenario, where: h.spec_id == ^spec.id, select: h.id))
      end)
    end
  end

  test "kiln_verifier role can SELECT holdout rows (narrow grant)" do
    {:ok, spec} = Specs.create_spec(%{title: "verifier read"})

    assert {:ok, %{id: hid}} =
             %HoldoutScenario{}
             |> HoldoutScenario.changeset(%{
               spec_id: spec.id,
               label: "golden",
               body: "holdout body"
             })
             |> Repo.insert()

    rows =
      with_role("kiln_verifier", fn ->
        Repo.all(from(h in HoldoutScenario, where: h.spec_id == ^spec.id, select: h.id))
      end)

    assert hid in rows
  end

  # 36-01 followup: kiln_verifier role/grants not yet created on the
  # Sigra-managed schema. Tracked in
  # .planning/todos/pending/2026-04-26-wire-real-sigra-controllers-36-01-followup.md
  @tag :skip
  test "VerifierReadRepo connects as kiln_verifier database role" do
    {:ok, _} = start_supervised(Kiln.Repo.VerifierReadRepo)
    :ok = Sandbox.checkout(Kiln.Repo.VerifierReadRepo)

    %{rows: [[who]]} = Kiln.Repo.VerifierReadRepo.query!("SELECT current_user")
    assert who == "kiln_verifier"
  end
end
