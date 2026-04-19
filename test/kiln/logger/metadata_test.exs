defmodule Kiln.Logger.MetadataTest do
  @moduledoc """
  Behaviors 22 + 23 + `with_metadata/2` reset semantics (D-45 + D-46).

  These tests are async: false because `:logger` handler config is
  global BEAM state — concurrent tests could attach conflicting
  handlers and see each other's log lines.
  """
  use ExUnit.Case, async: false

  import Kiln.LoggerCaptureHelper
  require Logger

  alias Kiln.Logger.Metadata

  setup do
    # Clear per-process metadata so earlier tests can't leak into this
    # test's capture. Logger.reset_metadata/1 with [] wipes everything.
    Logger.reset_metadata([])
    :ok
  end

  test "with_metadata/2 sets keys for the block and resets after" do
    {_result, lines} =
      capture_json(fn ->
        Metadata.with_metadata([correlation_id: "abc-123", run_id: "run-xyz"], fn ->
          Logger.info("inside_the_block")
        end)

        Logger.info("after_the_block")
      end)

    inside = Enum.find(lines, &(get_message(&1) == "inside_the_block"))
    after_line = Enum.find(lines, &(get_message(&1) == "after_the_block"))

    assert inside, "no line matched 'inside_the_block'; lines=#{inspect(lines)}"
    assert after_line, "no line matched 'after_the_block'; lines=#{inspect(lines)}"

    # correlation_id + run_id set inside the block
    assert get_metadata(inside, "correlation_id") == "abc-123"
    assert get_metadata(inside, "run_id") == "run-xyz"

    # After the block, metadata reset to prior (empty) — keys render as
    # "none" per the D-46 default-filter contract.
    assert get_metadata(after_line, "correlation_id") == "none"
    assert get_metadata(after_line, "run_id") == "none"
  end

  test "with_metadata/2 restores prior metadata even when fun raises" do
    Logger.metadata(correlation_id: "outer")

    {_, lines} =
      capture_json(fn ->
        assert_raise RuntimeError, "boom", fn ->
          Metadata.with_metadata([correlation_id: "inner"], fn ->
            Logger.info("inside_raise")
            raise "boom"
          end)
        end

        Logger.info("after_raise")
      end)

    inside = Enum.find(lines, &(get_message(&1) == "inside_raise"))
    after_line = Enum.find(lines, &(get_message(&1) == "after_raise"))

    assert get_metadata(inside, "correlation_id") == "inner"
    # prior metadata restored despite the raise
    assert get_metadata(after_line, "correlation_id") == "outer"
  end

  test "with_metadata/2 composes — nested calls merge and unwind correctly" do
    {_, lines} =
      capture_json(fn ->
        Metadata.with_metadata([correlation_id: "outer", actor: "planner"], fn ->
          Logger.info("outer_line")

          Metadata.with_metadata([actor: "coder", stage_id: "s1"], fn ->
            Logger.info("inner_line")
          end)

          Logger.info("after_inner")
        end)
      end)

    outer = Enum.find(lines, &(get_message(&1) == "outer_line"))
    inner = Enum.find(lines, &(get_message(&1) == "inner_line"))
    after_inner = Enum.find(lines, &(get_message(&1) == "after_inner"))

    assert get_metadata(outer, "correlation_id") == "outer"
    assert get_metadata(outer, "actor") == "planner"

    # Inner block inherits outer correlation_id, overrides actor, adds stage_id
    assert get_metadata(inner, "correlation_id") == "outer"
    assert get_metadata(inner, "actor") == "coder"
    assert get_metadata(inner, "stage_id") == "s1"

    # After inner exits, actor reverts to outer value, stage_id clears
    assert get_metadata(after_inner, "actor") == "planner"
    assert get_metadata(after_inner, "stage_id") == "none"
  end

  test "all six mandatory keys present on every log line (behavior 22 + 23)" do
    {_, lines} =
      capture_json(fn ->
        Logger.info("bare_line")
      end)

    line = Enum.find(lines, &(get_message(&1) == "bare_line"))
    assert line, "no line matched 'bare_line'; lines=#{inspect(lines)}"

    for key <- ~w(correlation_id causation_id actor actor_role run_id stage_id) do
      val = get_metadata(line, key)
      assert val != nil, "key #{key} must be present on every log line (lines=#{inspect(lines)})"
      # behavior 23: unset keys render as the string "none", not nil / null / missing
      assert val == "none",
             "unset key #{key} must render as \"none\" (got #{inspect(val)}; lines=#{inspect(lines)})"
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # JSON shape helpers — LoggerJSON.Formatters.Basic nests whitelisted
  # metadata keys under the "metadata" object at the top level. Reading
  # through both shapes keeps these assertions robust if a future plan
  # switches to GoogleCloud / Datadog formatters (which flatten).
  defp get_metadata(line, key), do: line["metadata"][key] || line[key]
  defp get_message(line), do: line["message"] || ""
end
