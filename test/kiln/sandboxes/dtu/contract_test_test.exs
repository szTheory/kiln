defmodule Kiln.Sandboxes.DTU.ContractTestTest do
  use ExUnit.Case, async: true

  alias Kiln.Sandboxes.DTU.{ContractTest, Supervisor}

  test "perform/1 is a no-op stub on the dtu queue" do
    assert ContractTest.__opts__()[:queue] == :dtu
    assert ContractTest.__opts__()[:max_attempts] == 1
    assert :ok == ContractTest.perform(%Oban.Job{args: %{}})
  end

  test "contract test cron remains disabled in config" do
    cron_entries =
      :kiln
      |> Application.fetch_env!(Oban)
      |> Keyword.fetch!(:plugins)
      |> Enum.find_value([], fn
        {Oban.Plugins.Cron, opts} -> Keyword.get(opts, :crontab, [])
        _ -> nil
      end)

    refute Enum.any?(cron_entries, fn {_expr, worker, _opts} -> worker == ContractTest end)
  end

  test "supervisor config includes the health poll child" do
    assert {:ok, {%{strategy: :one_for_one}, children}} = Supervisor.init([])

    assert Enum.any?(children, fn child ->
             Elixir.Supervisor.child_spec(
               Kiln.Sandboxes.DTU.HealthPoll,
               id: Kiln.Sandboxes.DTU.HealthPoll
             ) == child
           end)
  end
end
