defmodule Kiln.Credo.NoProcessPutTest do
  use Kiln.CredoTestCase

  alias Kiln.Credo.NoProcessPut

  test "flags Process.put/2" do
    """
    defmodule Sample do
      def bad, do: Process.put(:key, :value)
    end
    """
    |> to_source_file()
    |> run_check(NoProcessPut)
    |> assert_issue()
  end

  test "flags Process.put/1" do
    """
    defmodule Sample do
      def bad, do: Process.put(key: :value)
    end
    """
    |> to_source_file()
    |> run_check(NoProcessPut)
    |> assert_issue()
  end

  test "does not flag unrelated code" do
    """
    defmodule Sample do
      def ok, do: Enum.map([1, 2, 3], &(&1 * 2))
    end
    """
    |> to_source_file()
    |> run_check(NoProcessPut)
    |> refute_issues()
  end
end
