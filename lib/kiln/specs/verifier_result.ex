defmodule Kiln.Specs.VerifierResult do
  @moduledoc """
  SPEC-03 persisted verifier outcome: **machine verdict is authoritative**;
  LLM fields are explain-only (`allow_override` is always `false`).

  Maps are JSON-friendly (string keys) for JSV + audit payloads.
  """

  @schema_path Path.expand("../../../priv/jsv/verifier_result_v1.json", __DIR__)
  @external_resource @schema_path

  @root (case File.read(@schema_path) do
           {:ok, json} ->
             raw = Jason.decode!(json)

             JSV.build!(raw,
               default_meta: "https://json-schema.org/draft/2020-12/schema",
               formats: true
             )

           {:error, reason} ->
             raise "verifier_result_v1 missing: #{inspect(reason)}"
         end)

  defstruct [:verdict, :machine, :llm, :llm_disagreement, :allow_override]

  @type t :: %__MODULE__{
          verdict: :pass | :fail,
          machine: map(),
          llm: map(),
          llm_disagreement: boolean(),
          allow_override: false
        }

  @doc """
  Build from Phase A `machine` map and optional Phase B `llm` map (string keys).

  Invariant: if `machine["verdict"] == "fail"`, the final `verdict` is **always**
  `:fail` — LLM structured fields cannot promote to pass (non-override).
  """
  @spec build(map(), map()) :: {:ok, t()} | {:error, term()}
  def build(machine, llm \\ %{}) when is_map(machine) do
    llm = stringify_llm(llm)

    machine_verdict = parse_verdict(Map.get(machine, "verdict"))
    structured_verdict = llm |> Map.get("structured", %{}) |> Map.get("verdict")

    llm_implies_pass =
      structured_verdict == "pass" or structured_verdict == :pass

    machine_fail? = machine_verdict == :fail

    llm_disagreement = machine_fail? and llm_implies_pass

    verdict =
      if machine_fail? do
        :fail
      else
        :pass
      end

    out = %{
      "verdict" => Atom.to_string(verdict),
      "machine" => stringify_machine(machine),
      "llm" => llm,
      "llm_disagreement" => llm_disagreement,
      "allow_override" => false
    }

    case assert_non_override_invariant(out) do
      :ok ->
        case JSV.validate(out, @root) do
          {:ok, validated} -> {:ok, to_struct(validated)}
          {:error, err} -> {:error, {:schema_invalid, JSV.normalize_error(err)}}
        end

      {:error, _} = err ->
        err
    end
  end

  @spec build!(map(), map()) :: t()
  def build!(machine, llm \\ %{}) do
    case build(machine, llm) do
      {:ok, r} ->
        r

      {:error, reason} ->
        raise ArgumentError, "VerifierResult.build!/2 failed: #{inspect(reason)}"
    end
  end

  defp stringify_machine(m) do
    ec = Map.get(m, "exit_code") || Map.get(m, :exit_code)
    v = Map.get(m, "verdict") || Map.get(m, :verdict)

    %{
      "exit_code" => ec,
      "verdict" => verdict_to_string(v),
      "refs" => List.wrap(Map.get(m, "refs") || Map.get(m, :refs) || [])
    }
  end

  defp stringify_llm(%{} = llm) do
    struct = Map.get(llm, "structured") || Map.get(llm, :structured) || %{}
    nar = Map.get(llm, "narrative") || Map.get(llm, :narrative) || ""
    %{"structured" => deep_stringify(struct), "narrative" => to_string(nar)}
  end

  defp deep_stringify(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), deep_stringify_val(v)} end)
  end

  defp deep_stringify_val(v) when is_map(v), do: deep_stringify(v)
  defp deep_stringify_val(v) when is_list(v), do: Enum.map(v, &deep_stringify_val/1)
  defp deep_stringify_val(v), do: v

  defp verdict_to_string(v) when v in [:pass, "pass"], do: "pass"
  defp verdict_to_string(v) when v in [:fail, "fail"], do: "fail"
  defp verdict_to_string(v), do: to_string(v)

  defp parse_verdict("pass"), do: :pass
  defp parse_verdict("fail"), do: :fail
  defp parse_verdict(:pass), do: :pass
  defp parse_verdict(:fail), do: :fail

  defp assert_non_override_invariant(%{
         "verdict" => "pass",
         "machine" => %{"verdict" => "fail"}
       }) do
    {:error, :machine_fail_cannot_promote_to_pass}
  end

  defp assert_non_override_invariant(_), do: :ok

  defp to_struct(validated) do
    v =
      case validated["verdict"] do
        "pass" -> :pass
        "fail" -> :fail
      end

    %__MODULE__{
      verdict: v,
      machine: validated["machine"],
      llm: validated["llm"],
      llm_disagreement: validated["llm_disagreement"],
      allow_override: false
    }
  end
end
