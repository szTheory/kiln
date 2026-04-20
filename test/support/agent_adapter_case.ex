defmodule Kiln.AgentAdapterCase do
  @moduledoc """
  Shared ExUnit case template for `Kiln.Agents.Adapter` behaviour-contract
  tests. Imports `Mox`, wires `verify_on_exit!` + `set_mox_from_context`,
  and seeds a `correlation_id` into `Logger.metadata/1` so downstream
  audit-append / redaction assertions have a stable correlation key.

  The alias `Kiln.Agents.AdapterMock` is provided by `test/support/mocks.ex`
  (loaded by `test_helper.exs` before `ExUnit.start/1`). Wave 2
  (plan 03-05) ships the live `Kiln.Agents.Adapter` behaviour; the mock
  target resolves lazily at call time.

  ## Usage

      defmodule Kiln.Agents.Adapter.SomeTest do
        use Kiln.AgentAdapterCase, async: true

        test "mocked adapter observes a stub response" do
          Mox.stub(Kiln.Agents.AdapterMock, :complete, fn _, _ -> {:ok, :stub} end)
          assert {:ok, :stub} = Kiln.Agents.AdapterMock.complete(%{}, [])
        end
      end

  Composable with `Kiln.DataCase` / `Kiln.ObanCase` — a test can `use`
  multiple case templates; setup blocks compose in order.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Mox

      alias Kiln.Agents.AdapterMock

      setup :verify_on_exit!
      setup :set_mox_from_context
    end
  end

  setup _tags do
    Logger.metadata(correlation_id: Ecto.UUID.generate())
    :ok
  end
end
