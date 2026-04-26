defmodule Kiln.AuditBridgeTest do
  use KilnWeb.ConnCase, async: false

  import Ecto.Query

  alias Kiln.Audit
  alias Kiln.Audit.Event
  alias Kiln.Operators.Operator
  alias Kiln.Operators.UserPasskey
  alias Kiln.Repo
  import Kiln.OperatorsFixtures, only: [valid_user_password: 0]

  describe "auth audit forwarding" do
    test "password sign-in appends an auth event into Kiln.Audit", %{conn: conn} do
      operator = confirmed_operator_fixture()
      before_count = Repo.aggregate(Event, :count)

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => operator.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == ~p"/"
      assert Repo.aggregate(Event, :count) == before_count + 1

      event = Repo.one(from e in Event, order_by: [desc: e.occurred_at, desc: e.id], limit: 1)
      assert event.actor_id == operator.id
      assert event.payload["action"] == "auth.login.success"
      assert event.payload["method"] == "password"
    end

    test "passkey sign-in appends an auth event into Kiln.Audit", %{conn: conn} do
      operator = confirmed_operator_fixture()
      passkey = passkey_fixture(operator)
      before_count = Repo.aggregate(Event, :count)

      conn = issue_passkey_challenge(conn, :authentication)

      stub_passkey_ceremony(fn
        {:authenticate, authenticated_operator, _response, _opts} ->
          assert authenticated_operator.id == operator.id
          {:ok, authenticated_operator, passkey}
      end)

      conn =
        post(conn, ~p"/users/log_in/passkey", %{
          "user" => %{"email" => operator.email},
          "passkey" => %{
            "response" =>
              encoded_passkey_response(%{
                credential_id: passkey.credential_id,
                user_handle: operator.id
              })
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Repo.aggregate(Event, :count) == before_count + 1

      event = Repo.one(from e in Event, order_by: [desc: e.occurred_at, desc: e.id], limit: 1)
      assert event.actor_id == operator.id
      assert event.payload["action"] == "auth.login.success"
      assert event.payload["method"] == "passkey"
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

  defp passkey_fixture(operator, attrs \\ %{}) do
    defaults = %{
      user_id: operator.id,
      credential_id: "credential-#{System.unique_integer([:positive])}",
      public_key: "test-public-key",
      sign_count: 0,
      aaguid: "00000000-0000-0000-0000-000000000000",
      nickname: "Test passkey",
      device_hint: "Test Device",
      transports: ["internal"],
      rp_id: "localhost"
    }

    %UserPasskey{}
    |> UserPasskey.create_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp issue_passkey_challenge(conn, ceremony) do
    conn = Phoenix.ConnTest.init_test_session(conn, %{})
    bytes = "test-#{ceremony}-challenge"

    {conn, _challenge} =
      Sigra.Plug.PasskeyChallenge.issue(conn, ceremony, Sigra.Passkeys.config(), bytes: bytes)

    conn
  end

  defp encoded_passkey_response(attrs \\ %{}) do
    credential_id = Map.get(attrs, :credential_id) || Map.get(attrs, "credential_id")
    user_handle = Map.get(attrs, :user_handle) || Map.get(attrs, "user_handle")
    encoded_credential_id = Base.url_encode64(credential_id, padding: false)

    response =
      %{
        "clientDataJSON" =>
          Base.url_encode64(~s({"type":"webauthn.get","challenge":"test"}), padding: false),
        "authenticatorData" => Base.url_encode64("authenticator-data", padding: false),
        "signature" => Base.url_encode64("signature", padding: false),
        "userHandle" =>
          if(user_handle,
            do: Base.url_encode64(to_string(user_handle), padding: false),
            else: nil
          ),
        "attestationObject" => Base.url_encode64("attestation-object", padding: false),
        "transports" => ["internal"]
      }
      |> Map.reject(fn {_key, value} -> is_nil(value) end)

    %{
      "id" => encoded_credential_id,
      "rawId" => encoded_credential_id,
      "type" => "public-key",
      "response" => response
    }
    |> Jason.encode!()
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

    @key {Kiln.AuditBridgeTest, :passkey_ceremony}

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
