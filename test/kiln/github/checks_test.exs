defmodule Kiln.GitHub.ChecksTest do
  use ExUnit.Case, async: true

  alias Kiln.GitHub.Checks

  @fixture_path "test/fixtures/github/check_runs.json"

  test "summarize/2 builds predicate from fixture (required pass, optional fail ignored)" do
    {:ok, json} = Jason.decode(File.read!(@fixture_path))

    assert {:ok, summary} =
             Checks.summarize(json, %{
               required_check_names: ["required-unit", "required-lint"],
               is_draft: false
             })

    assert summary.predicate_pass == true
    assert length(summary.required) == 2
    assert length(summary.optional) == 1
    assert hd(summary.optional).name == "optional-flake"
  end

  test "draft forces predicate_pass false" do
    {:ok, json} = Jason.decode(File.read!(@fixture_path))

    assert {:ok, %{predicate_pass: false}} =
             Checks.summarize(json, %{
               required_check_names: ["required-unit", "required-lint"],
               is_draft: true
             })
  end

  test "missing check_runs returns checks_transport_unsupported" do
    assert Checks.summarize(%{"statuses" => []}, %{required_check_names: ["x"]}) ==
             {:error, :checks_transport_unsupported}
  end
end
