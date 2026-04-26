defmodule KilnWeb.SessionControllerTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  import Kiln.OperatorsFixtures
  alias Kiln.Repo

  describe "GET /users/log_in" do
    test "renders password and passkey controls", %{conn: conn} do
      body = conn |> get(~p"/users/log_in") |> html_response(200)

      assert body =~ ~s(id="login_form")
      assert body =~ ~s(id="passkey_login_form")
      assert body =~ "Continue with passkey"
      assert body =~ "Log in"
    end
  end

  describe "POST /users/log_in" do
    test "invalid credentials stay enumeration-safe and redirect back to login", %{conn: conn} do
      user = confirmed_user_fixture()

      for params <- [
            %{"user" => %{"email" => user.email, "password" => "wrong-password"}},
            %{"user" => %{"email" => "missing@example.com", "password" => "wrong-password"}}
          ] do
        conn = post(conn, ~p"/users/log_in", params)

        assert redirected_to(conn) == ~p"/users/log_in"
      end
    end

    test "successful password login establishes a signed operator session", %{conn: conn} do
      user = confirmed_user_fixture()

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == ~p"/"
      assert Plug.Conn.get_session(conn, :user_token)

      {:ok, view, _html} = live(recycle(conn), ~p"/")
      assert has_element?(view, "#run-board")
    end
  end

  describe "POST /users/log_in/passkey" do
    test "successful passkey login establishes a signed operator session", %{conn: conn} do
      %{user: user, passkey: passkey, response: response} =
        authenticate_with_passkey(confirmed_user_fixture())

      conn = issue_passkey_challenge(conn, :authentication)

      stub_passkey_ceremony(fn
        {:authenticate, authenticated_user, _response, _opts} ->
          assert authenticated_user.id == user.id
          {:ok, authenticated_user, passkey}
      end)

      conn =
        post(conn, ~p"/users/log_in/passkey", %{
          "user" => %{"email" => user.email},
          "passkey" => %{
            "response" => response
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Plug.Conn.get_session(conn, :user_token)

      {:ok, view, _html} = live(recycle(conn), ~p"/")
      assert has_element?(view, "#run-board")
    end
  end

  defp confirmed_user_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    user
    |> Kiln.Operators.Operator.confirm_changeset()
    |> Repo.update!()
  end

  defp issue_passkey_challenge(conn, ceremony) do
    conn = Phoenix.ConnTest.init_test_session(conn, %{})
    bytes = "test-#{ceremony}-challenge"

    {conn, _challenge} =
      Sigra.Plug.PasskeyChallenge.issue(conn, ceremony, Sigra.Passkeys.config(), bytes: bytes)

    conn
  end

  defp stub_passkey_ceremony(result_fun) when is_function(result_fun, 1) do
    key = {__MODULE__, :passkey_ceremony}
    old_env = Application.get_env(:kiln, :passkey_ceremony_module)

    :persistent_term.put(key, result_fun)
    Application.put_env(:kiln, :passkey_ceremony_module, __MODULE__.PasskeyCeremonyStub)

    on_exit(fn ->
      :persistent_term.erase(key)

      if is_nil(old_env) do
        Application.delete_env(:kiln, :passkey_ceremony_module)
      else
        Application.put_env(:kiln, :passkey_ceremony_module, old_env)
      end
    end)

    :ok
  end

  defmodule PasskeyCeremonyStub do
    @moduledoc false

    @key {KilnWeb.SessionControllerTest, :passkey_ceremony}

    def authenticate(config, email_or_user, response, opts),
      do: authenticate_passkey(config, email_or_user, response, opts)

    def register(config, user, response, opts),
      do: register_passkey(config, user, response, opts)

    def authenticate_passkey(_config, email_or_user, response, opts) do
      :persistent_term.get(@key).({:authenticate, email_or_user, response, opts})
    end

    def register_passkey(_config, user, response, opts) do
      :persistent_term.get(@key).({:register, user, response, opts})
    end
  end
end
