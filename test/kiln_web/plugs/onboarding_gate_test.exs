defmodule KilnWeb.OnboardingGateTest do
  use KilnWeb.ConnCase, async: false

  alias Kiln.OperatorReadiness

  test "does not redirect when readiness is incomplete", %{conn: conn} do
    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, false)

    try do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Runs"
    after
      assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, true)
    end
  end
end
