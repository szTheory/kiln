defmodule Kiln.TestMocksTest do
  @moduledoc """
  Wave 0 smoke test. Proves the new Phase 3 deps compile, the Mox
  defmocks register, and the Bypass-based stub server spins up on a
  dynamic port. If this file fails, the rest of Phase 3's test suite
  cannot even compile.

  Lives under `test/support/` (not `test/kiln/`) because plan 03-00's
  acceptance-criteria command is `mix test test/support/mocks_test.exs`.
  `mix test <path>` accepts an explicit `.exs` file and does not require
  the path to be under the default discovery root.
  """

  use ExUnit.Case, async: true

  test "Kiln.Agents.AdapterMock is defined as a Mox mock" do
    assert Code.ensure_loaded?(Kiln.Agents.AdapterMock)
  end

  test "Kiln.Sandboxes.DriverMock is defined as a Mox mock" do
    assert Code.ensure_loaded?(Kiln.Sandboxes.DriverMock)
  end

  test "Kiln.AnthropicStubServer.start! returns a usable Bypass handle" do
    stub = Kiln.AnthropicStubServer.start!()
    assert is_integer(stub.port)
    assert stub.port > 0
    assert stub.base_url =~ ~r|^http://localhost:\d+$|
  end

  test "Kiln.DockerHelper.docker_available?/0 returns boolean" do
    assert is_boolean(Kiln.DockerHelper.docker_available?())
  end
end
