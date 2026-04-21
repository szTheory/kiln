defmodule Kiln.Agents.Roles.QAVerifierTest do
  use ExUnit.Case, async: false

  import Mox

  alias Kiln.Agents.AdapterMock
  alias Kiln.Agents.Prompt
  alias Kiln.Agents.Response
  alias Kiln.Agents.Roles.QAVerifier

  setup :verify_on_exit!

  test "machine fail + LLM JSON pass stays verdict fail with llm_disagreement" do
    expect(AdapterMock, :complete, fn %Prompt{} = p, opts ->
      assert Keyword.get(opts, :temperature) == 0
      assert p.temperature == 0.0
      body = Jason.encode!(%{"verdict" => "pass", "notes" => "LGTM"})
      {:ok, %Response{content: body, stop_reason: :end_turn}}
    end)

    r = QAVerifier.run_machine_llm(AdapterMock, 1, refs: ["scenario-a"])
    assert r.verdict == :fail
    assert r.llm_disagreement == true

    diag = QAVerifier.diagnostic_for_planner(r)
    assert diag["llm_disagreement"] == true
    assert diag["verdict"] == "fail"
    assert diag["failing_test_ids"] == ["scenario-a"]
  end

  test "machine pass skips adapter" do
    r = QAVerifier.run_machine_llm(AdapterMock, 0)
    assert r.verdict == :pass
    assert r.llm_disagreement == false
  end
end
