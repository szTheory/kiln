defmodule Kiln.WorkUnitsCliSafetyTest do
  use ExUnit.Case, async: true

  test "no destructive Mix.Tasks.Kiln.WorkUnits.* modules ship in Phase 4" do
    refute Code.ensure_loaded?(Mix.Tasks.Kiln.WorkUnits)
    refute Code.ensure_loaded?(Mix.Tasks.Kiln.WorkUnits.Delete)
    refute Code.ensure_loaded?(Mix.Tasks.Kiln.WorkUnits.Reset)
  end

  test "JsonlAdapter stays export-only in source" do
    source = File.read!("lib/kiln/work_units/jsonl_adapter.ex")
    assert source =~ "def export_run"
    refute source =~ "def import_run"
    refute source =~ "def delete_run"
  end
end
