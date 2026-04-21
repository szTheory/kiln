defmodule Kiln.Specs.VerifierResultTest do
  use ExUnit.Case, async: true

  alias Kiln.Specs.VerifierResult

  test "machine fail + LLM structured pass → verdict fail + llm_disagreement" do
    {:ok, r} =
      VerifierResult.build(
        %{"exit_code" => 1, "verdict" => "fail", "refs" => ["t1"]},
        %{"structured" => %{"verdict" => "pass"}, "narrative" => "looks ok"}
      )

    assert r.verdict == :fail
    assert r.llm_disagreement == true
    assert r.allow_override == false
  end

  test "machine pass ignores LLM fail for verdict" do
    {:ok, r} =
      VerifierResult.build(
        %{"exit_code" => 0, "verdict" => "pass", "refs" => []},
        %{"structured" => %{"verdict" => "fail"}, "narrative" => "nope"}
      )

    assert r.verdict == :pass
    assert r.llm_disagreement == false
  end

  test "JSV rejects invalid envelope" do
    bad = %{
      "verdict" => "pass",
      "machine" => %{"exit_code" => 0, "verdict" => "pass", "refs" => []},
      "llm" => %{"structured" => %{}, "narrative" => ""},
      "llm_disagreement" => false,
      "allow_override" => true
    }

    root =
      __DIR__
      |> Path.join("../../../priv/jsv/verifier_result_v1.json")
      |> Path.expand()
      |> File.read!()
      |> Jason.decode!()
      |> JSV.build!(default_meta: "https://json-schema.org/draft/2020-12/schema", formats: true)

    assert {:error, _} = JSV.validate(bad, root)
  end
end
