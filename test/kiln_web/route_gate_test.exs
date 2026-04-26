defmodule KilnWeb.RouteGateTest do
  use KilnWeb.ConnCase, async: false

  @moduletag :anonymous

  import Phoenix.LiveViewTest
  import Kiln.OperatorsFixtures, only: [valid_user_password: 0]

  alias Kiln.Operators.Operator
  alias Kiln.Repo

  describe "remote dashboard route gate" do
    test "/health stays public while dashboard routes redirect unauthenticated visitors", %{
      conn: conn
    } do
      assert get(conn, "/health").status == 200

      for path <- [~p"/", ~p"/templates", ~p"/inbox", ~p"/settings", ~p"/audit"] do
        assert_login_redirect(conn, path)
      end
    end

    test "authenticated access still reaches the dashboard", %{conn: conn} do
      operator = confirmed_operator_fixture()

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => operator.email, "password" => valid_user_password()}
        })

      {:ok, view, _html} = live(recycle(conn), ~p"/")

      assert has_element?(view, "#run-board")
      assert has_element?(view, "#run-board-overview")
    end
  end

  defp assert_login_redirect(conn, path) do
    case live(conn, path) do
      {:error, {:redirect, %{to: to}}} -> assert to == ~p"/users/log_in"
      {:error, {:live_redirect, %{to: to}}} -> assert to == ~p"/users/log_in"
      other -> flunk("unexpected response for #{path}: #{inspect(other)}")
    end
  end

  defp confirmed_operator_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: "operator#{System.unique_integer()}@example.com",
        password: "hello world!!"
      })

    operator =
      %Operator{}
      |> Operator.registration_changeset(attrs)
      |> Repo.insert!()

    operator
    |> Operator.confirm_changeset()
    |> Repo.update!()
  end
end
