defmodule Kiln.OperatorRuntimeTest do
  # Application env is process-global — serialize to avoid cross-test races.
  use ExUnit.Case, async: false

  alias Kiln.OperatorRuntime

  setup do
    prior = Application.get_env(:kiln, :operator_runtime_mode)

    on_exit(fn ->
      if prior == nil do
        Application.delete_env(:kiln, :operator_runtime_mode)
      else
        Application.put_env(:kiln, :operator_runtime_mode, prior, persistent: false)
      end
    end)

    %{prior_mode: prior}
  end

  test "mode/0 returns :demo when configured" do
    Application.put_env(:kiln, :operator_runtime_mode, :demo, persistent: false)
    assert OperatorRuntime.mode() == :demo
  end

  test "mode/0 returns :live when configured" do
    Application.put_env(:kiln, :operator_runtime_mode, :live, persistent: false)
    assert OperatorRuntime.mode() == :live
  end

  test "mode/0 returns :unknown for nil or unexpected atoms" do
    Application.put_env(:kiln, :operator_runtime_mode, nil, persistent: false)
    assert OperatorRuntime.mode() == :unknown

    Application.put_env(:kiln, :operator_runtime_mode, :oops, persistent: false)
    assert OperatorRuntime.mode() == :unknown
  end

  test "normalize/1 accepts strings and atoms" do
    assert OperatorRuntime.normalize(:demo) == :demo
    assert OperatorRuntime.normalize("live") == :live
    assert OperatorRuntime.normalize("nope") == :unknown
  end
end
