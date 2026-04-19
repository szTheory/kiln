defmodule KilnWeb.ConnCase do
  @moduledoc """
  ExUnit case template for controller + plug tests: builds a fresh
  `Plug.Conn` per test and wraps each test in an Ecto SQL sandbox so
  HTTP-level writes are rolled back at test exit. Use
  `use KilnWeb.ConnCase, async: true` for parallel Postgres runs.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint KilnWeb.Endpoint

      use KilnWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import KilnWeb.ConnCase
    end
  end

  setup tags do
    Kiln.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
