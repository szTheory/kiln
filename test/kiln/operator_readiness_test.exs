defmodule Kiln.OperatorReadinessTest do
  use Kiln.DataCase, async: true

  alias Kiln.OperatorReadiness

  test "ready? reflects persisted flags" do
    assert OperatorReadiness.ready?()
    assert {:ok, _} = OperatorReadiness.mark_step(:github, false)
    refute OperatorReadiness.ready?()
    assert {:ok, _} = OperatorReadiness.mark_step(:github, true)
    assert OperatorReadiness.ready?()
  end
end
