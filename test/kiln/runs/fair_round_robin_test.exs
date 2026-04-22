defmodule Kiln.Runs.FairRoundRobinTest do
  use ExUnit.Case, async: true

  alias Kiln.Runs.{FairRoundRobin, Run}

  defp run(id, inserted_at) do
    struct!(Run,
      id: id,
      inserted_at: inserted_at,
      updated_at: inserted_at
    )
  end

  test "order/2 — nil cursor is stable FIFO by inserted_at then id" do
    t0 = ~U[2024-01-01 00:00:00.000000Z]
    t1 = ~U[2024-01-02 00:00:00.000000Z]
    a = run("aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa", t1)
    b = run("bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb", t0)
    c = run("cccccccc-cccc-4ccc-cccc-cccccccccccc", t0)

    ordered = FairRoundRobin.order([a, c, b], nil)
    assert Enum.map(ordered, & &1.id) == [b.id, c.id, a.id]
  end

  test "order/2 — rotates so the run after cursor is first (N=3)" do
    t = ~U[2024-06-01 12:00:00.000000Z]
    a = run("10000000-0000-4000-8000-000000000001", t)
    b = run("20000000-0000-4000-8000-000000000002", t)
    c = run("30000000-0000-4000-8000-000000000003", t)

    sorted = FairRoundRobin.order([c, a, b], nil)
    assert Enum.map(sorted, & &1.id) == [a.id, b.id, c.id]

    assert FairRoundRobin.order([c, a, b], a.id) |> hd() |> Map.fetch!(:id) == b.id
    assert FairRoundRobin.order([c, a, b], b.id) |> hd() |> Map.fetch!(:id) == c.id
    assert FairRoundRobin.order([c, a, b], c.id) |> hd() |> Map.fetch!(:id) == a.id
  end

  test "order/2 — stale cursor falls back to sorted order" do
    t = ~U[2024-01-01 00:00:00.000000Z]
    a = run("aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa", t)
    b = run("bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb", t)

    ordered = FairRoundRobin.order([b, a], "00000000-0000-4000-8000-000000000000")
    assert Enum.map(ordered, & &1.id) == [a.id, b.id]
  end

  test "order/2 — N=1" do
    t = ~U[2024-01-01 00:00:00.000000Z]
    a = run("aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa", t)
    assert FairRoundRobin.order([a], nil) == [a]
    assert FairRoundRobin.order([a], a.id) == [a]
  end
end
