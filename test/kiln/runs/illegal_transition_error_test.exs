defmodule Kiln.Runs.IllegalTransitionErrorTest do
  use ExUnit.Case, async: true
  alias Kiln.Runs.IllegalTransitionError

  test "exception/1 constructs a message with from/to/allowed substrings" do
    e =
      IllegalTransitionError.exception(
        run_id: "abc",
        from: :queued,
        to: :merged,
        allowed: [:planning, :escalated, :failed]
      )

    assert e.message =~ "from "
    assert e.message =~ "to "
    assert e.message =~ "allowed from"
    assert e.message =~ "queued"
    assert e.message =~ "merged"
  end

  test "exception/1 preserves the fields passed in" do
    e =
      IllegalTransitionError.exception(
        run_id: "r-1",
        from: :planning,
        to: :merged,
        allowed: [:coding, :blocked, :escalated, :failed]
      )

    assert e.run_id == "r-1"
    assert e.from == :planning
    assert e.to == :merged
    assert e.allowed == [:coding, :blocked, :escalated, :failed]
  end

  test "raises cleanly via raise/2" do
    assert_raise IllegalTransitionError, ~r/from.*to.*allowed/, fn ->
      raise IllegalTransitionError,
        run_id: "x",
        from: :merged,
        to: :planning,
        allowed: []
    end
  end

  test "allowed list defaults to [] when omitted" do
    e = IllegalTransitionError.exception(run_id: "r", from: :not_found, to: :planning)
    assert e.allowed == []
    assert e.message =~ "not_found"
  end
end
