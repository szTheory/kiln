defmodule KilnWeb.OnboardingGateTest do
  use KilnWeb.ConnCase, async: false

  alias Kiln.OperatorReadiness

  test "redirects to onboarding when readiness is incomplete", %{conn: conn} do
    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, false)

    try do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == "/onboarding"
    after
      assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, true)
    end
  end
end
