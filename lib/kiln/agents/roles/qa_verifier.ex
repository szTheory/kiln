defmodule Kiln.Agents.Roles.QAVerifier do
  @moduledoc """
  QA Verifier **role** (`GenServer` work-unit claiming) plus a **pure**
  machine-first / LLM-second verification orchestration entrypoint for
  ORCH-05 (`run_machine_llm/3`).

  ## Planner loop-back (`diagnostic_for_planner/1`)

  Returns string-keyed map:

    * `"failing_test_ids"` — list of scenario / test ids from `machine.refs`
    * `"verdict"` — `"pass"` | `"fail"`
    * `"llm_disagreement"` — boolean
    * `"machine_exit_code"` — integer
  """

  use Kiln.Agents.Role, role: :qa_verifier

  alias Kiln.Agents
  alias Kiln.Agents.Prompt
  alias Kiln.Agents.Response
  alias Kiln.Specs.VerifierResult

  @doc """
  Phase **A**: `machine_exit_code` → machine verdict (`0` = pass).
  Phase **B** (only on machine fail): call `adapter` with `temperature: 0`,
  parse JSON content, feed `VerifierResult.build/2`.
  """
  @spec run_machine_llm(module(), integer(), keyword()) :: VerifierResult.t()
  def run_machine_llm(adapter, machine_exit_code, opts \\ [])
      when is_atom(adapter) and is_integer(machine_exit_code) do
    machine_verdict = if machine_exit_code == 0, do: "pass", else: "fail"

    machine = %{
      "exit_code" => machine_exit_code,
      "verdict" => machine_verdict,
      "refs" => Keyword.get(opts, :refs, [])
    }

    llm =
      if machine_verdict == "pass" do
        %{"structured" => %{}, "narrative" => ""}
      else
        prompt = llm_prompt()

        case Agents.complete(adapter, prompt, temperature: 0.0, max_tokens: 800) do
          {:ok, %Response{content: content}} when is_binary(content) ->
            decode_llm_map(content)

          {:ok, %Response{content: %{} = map}} ->
            %{"structured" => map, "narrative" => ""}

          _ ->
            %{"structured" => %{"verdict" => "pass"}, "narrative" => "unparseable_llm_response"}
        end
      end

    VerifierResult.build!(machine, llm)
  end

  defp llm_prompt do
    %Prompt{
      model: "stub",
      system:
        "Reply with JSON only: {\"verdict\":\"pass\"|\"fail\",\"notes\":\"...\"} — verdict is advisory only.",
      messages: [%{role: :user, content: "Machine tests failed. Explain."}],
      temperature: 0.0
    }
  end

  defp decode_llm_map(bin) do
    case Jason.decode(bin) do
      {:ok, map} when is_map(map) ->
        %{"structured" => map, "narrative" => Map.get(map, "notes", "")}

      _ ->
        %{"structured" => %{"verdict" => "pass"}, "narrative" => "invalid_json"}
    end
  end

  @spec diagnostic_for_planner(VerifierResult.t()) :: map()
  def diagnostic_for_planner(%VerifierResult{} = r) do
    refs = Map.get(r.machine, "refs", [])

    %{
      "failing_test_ids" => refs,
      "verdict" => Atom.to_string(r.verdict),
      "llm_disagreement" => r.llm_disagreement,
      "machine_exit_code" => Map.get(r.machine, "exit_code")
    }
  end
end
