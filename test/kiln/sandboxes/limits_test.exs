defmodule Kiln.Sandboxes.LimitsTest do
  use ExUnit.Case, async: false

  alias Kiln.Sandboxes.Limits

  import ExUnit.CaptureLog

  setup do
    Limits.load!()
    :ok
  end

  test "for_stage(:default) returns the default profile" do
    limits = Limits.for_stage(:default)

    assert limits["memory"] == "768m"
    assert limits["cpus"] == 1
    assert limits["pids_limit"] == 256
  end

  test "for_stage(:coding) returns the permissive profile" do
    limits = Limits.for_stage(:coding)

    assert limits["memory"] == "2g"
    assert limits["cpus"] == 2
    assert limits["pids_limit"] == 512
  end

  test "for_stage(:unknown) falls back to default and logs a warning" do
    log =
      capture_log(fn ->
        assert Limits.for_stage(:totally_unknown)["memory"] == "768m"
      end)

    assert log =~ "unknown stage kind"
  end

  test "all_stage_kinds includes default, coding, testing, and merge" do
    kinds = Limits.all_stage_kinds()

    for kind <- ["default", "coding", "testing", "merge"] do
      assert kind in kinds
    end
  end
end
