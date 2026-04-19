defmodule Kiln.Credo.NoMixEnvAtRuntimeTest do
  use Kiln.CredoTestCase

  alias Kiln.Credo.NoMixEnvAtRuntime

  test "flags Mix.env() in a runtime-reachable module" do
    """
    defmodule Sample do
      def which, do: Mix.env()
    end
    """
    |> to_source_file("lib/sample.ex")
    |> run_check(NoMixEnvAtRuntime)
    |> assert_issue()
  end

  test "does NOT flag Mix.env() inside mix.exs" do
    """
    defmodule Kiln.MixProject do
      use Mix.Project
      def project, do: [app: :kiln, env: Mix.env()]
    end
    """
    |> to_source_file("mix.exs")
    |> run_check(NoMixEnvAtRuntime)
    |> refute_issues()
  end
end
