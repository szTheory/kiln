defmodule Kiln.DataCase do
  @moduledoc """
  ExUnit case template for data-layer tests: wraps each test in an Ecto
  SQL sandbox so schema mutations are rolled back at test exit. Use
  `use Kiln.DataCase, async: true` for transaction-isolated parallel runs
  (Postgres-only — other adapters do not guarantee sandbox isolation).
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Kiln.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Kiln.DataCase
    end
  end

  setup tags do
    Kiln.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Kiln.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
