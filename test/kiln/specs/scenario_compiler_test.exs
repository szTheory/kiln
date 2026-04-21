defmodule Kiln.Specs.ScenarioCompilerTest do
  use Kiln.DataCase, async: false

  alias Kiln.Specs
  alias Kiln.Specs.ScenarioCompiler

  @fixture Path.expand("../../fixtures/specs/minimal_spec.md", __DIR__)

  test "compile writes generated test under revision uuid directory and mix test passes" do
    {:ok, spec} = Specs.create_spec(%{title: "compile-target"})
    body = File.read!(@fixture)
    {:ok, rev} = Specs.create_revision(spec, %{body: body})

    updated = Specs.compile_revision!(rev)
    assert byte_size(updated.scenario_manifest_sha256) == 64

    uuid = Ecto.UUID.cast!(rev.id)
    rel = Path.join(["test", "generated", "kiln_scenarios", uuid, "scenarios_test.exs"])
    abs = Path.join(File.cwd!(), rel)
    assert File.exists?(abs)
    src = File.read!(abs)
    assert src =~ "defmodule Kiln.GeneratedScenarios.R"
    assert src =~ "use ExUnit.Case"
    assert src =~ "@moduletag :kiln_scenario"
    assert src =~ "revision_id: #{uuid}"

    {out, code} =
      System.cmd(
        "mix",
        ["test", rel, "--include", "kiln_scenario", "--max-failures", "1"],
        cd: File.cwd!(),
        stderr_to_stdout: true
      )

    assert code == 0, out
  end

  test "failing expect false yields non-zero mix test exit" do
    {:ok, spec} = Specs.create_spec(%{title: "fail-target"})

    body = """
    ```kiln-scenario
    scenarios:
      - id: willfail
        description: boom
        steps:
          - kind: assert
            expect: "false"
    ```
    """

    {:ok, rev} = Specs.create_revision(spec, %{body: body})
    Specs.compile_revision!(rev)

    uuid = Ecto.UUID.cast!(rev.id)
    rel = Path.join(["test", "generated", "kiln_scenarios", uuid, "scenarios_test.exs"])

    {out, code} =
      System.cmd(
        "mix",
        ["test", rel, "--include", "kiln_scenario", "--max-failures", "1"],
        cd: File.cwd!(),
        stderr_to_stdout: true
      )

    assert code != 0, out
  end

  test "manifest_sha256 is stable for sorted scenario ids" do
    ir = %{
      "scenarios" => [
        %{
          "id" => "b",
          "description" => "",
          "steps" => [%{"kind" => "assert", "expect" => "true"}]
        },
        %{
          "id" => "a",
          "description" => "",
          "steps" => [%{"kind" => "assert", "expect" => "true"}]
        }
      ]
    }

    h1 = ScenarioCompiler.manifest_sha256(ir)
    h2 = ScenarioCompiler.manifest_sha256(%{ir | "scenarios" => Enum.reverse(ir["scenarios"])})
    assert h1 == h2
  end
end
