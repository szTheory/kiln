defmodule Kiln.Workflows.Compiler do
  @moduledoc """
  Transforms a JSV-validated workflow map into a `%Kiln.Workflows.CompiledGraph{}`.

  Runs the 6 D-62 Elixir-side validators that JSON Schema alone cannot
  express (structural DAG properties + v1 signature invariant), then
  topologically sorts and computes a deterministic sha256 checksum
  (D-94) over the shape-significant fields.

  ## D-62 validators (executed in this order)

    1. `signature: null` — v1 invariant (D-65 reservation). Populated
       signatures are rejected before any graph work.
    2. Exactly one stage has `depends_on: []` — the unique entry node.
    3. `Kiln.Workflows.Graph.topological_sort/1` succeeds — DAG is
       acyclic and every `depends_on` id resolves to a stage in the
       same workflow (combined validator 2 + 3).
    4. Every `on_failure.to` is a strict topological ancestor (prevents
       forward-edge infinite loops — D-62 validator 4).
    5. Every `kind` has a registered contract (via
       `Kiln.Stages.ContractRegistry.fetch/1`) — D-62 validator 5 / P4
       token-bloat boundary defence.

  ## Error shape

  `{:error, {:graph_invalid, reason, detail}}` where `reason` is one of:

    * `:signature_must_be_null` — D-62 validator 6 (v1 invariant)
    * `:no_entry_node` — zero stages with `depends_on: []`
    * `:multiple_entry_nodes` — more than one stage with `depends_on: []`
    * `:cycle` — `:digraph` rejected a back-edge or topsort failed
    * `{:missing_dep, dep_id}` — a `depends_on` points to a non-existent stage
    * `:on_failure_forward_edge` — a stage routes on_failure to a
      descendant or sibling instead of a strict ancestor
    * `{:unknown_kind, kind}` — a stage's `kind` has no matching contract
      registered in `Kiln.Stages.ContractRegistry`

  `detail` is a map with the minimum diagnostic information the
  Loader can normalise + audit callers can render.

  ## Checksum

  Uses `:crypto.hash(:sha256, ...)` over
  `:erlang.term_to_binary(term, [:deterministic])`. The term contains
  only shape-significant fields (id, version, api_version, model_profile,
  caps, per-stage tuples in topological order). Determinism across nodes
  and runs is a structural guarantee — no map iteration order concerns.
  """

  alias Kiln.Stages.ContractRegistry
  alias Kiln.Workflows.{CompiledGraph, Graph}

  # D-58 bounded enums — mirrored from the JSON schema. JSV has already
  # validated the string values belong to these sets; we use explicit
  # String -> atom maps (not `String.to_existing_atom/1`) because:
  #
  #   * atoms may not be loaded into the BEAM at the moment Compiler runs
  #     (e.g. a `mix run` that hasn't yet referenced Kiln.Stages.StageRun)
  #   * explicit mapping makes the enum SSOT visible for review
  #   * the compile-time-built @kind_atoms module attribute ensures atom
  #     existence at Compiler's own compile time (safe under `mix run`)
  @kind_atoms %{
    "planning" => :planning,
    "coding" => :coding,
    "testing" => :testing,
    "verifying" => :verifying,
    "merge" => :merge
  }

  @agent_role_atoms %{
    "planner" => :planner,
    "coder" => :coder,
    "tester" => :tester,
    "reviewer" => :reviewer,
    "uiux" => :uiux,
    "qa_verifier" => :qa_verifier,
    "mayor" => :mayor
  }

  @sandbox_atoms %{
    "none" => :none,
    "readonly" => :readonly,
    "readwrite" => :readwrite
  }

  @type error_reason ::
          :signature_must_be_null
          | :no_entry_node
          | :multiple_entry_nodes
          | :cycle
          | {:missing_dep, String.t()}
          | :on_failure_forward_edge
          | {:unknown_kind, atom()}

  @spec compile(map()) ::
          {:ok, CompiledGraph.t()}
          | {:error, {:graph_invalid, error_reason(), map()}}
  def compile(raw) when is_map(raw) do
    with :ok <- validate_signature_null(raw),
         {:ok, stages_raw} <- fetch_stages(raw),
         {:ok, normalized} <- normalize_stages(stages_raw),
         :ok <- validate_single_entry(normalized),
         :ok <- validate_all_kinds_have_contracts(normalized),
         {:ok, sorted_ids} <- topological_sort(normalized),
         :ok <- validate_on_failure_ancestors(normalized, sorted_ids),
         {:ok, entry_id} <- find_entry(normalized) do
      stages_ordered =
        Enum.map(sorted_ids, fn id -> Enum.find(normalized, &(&1.id == id)) end)

      stages_by_id = Map.new(normalized, &{&1.id, &1})

      base = %CompiledGraph{
        id: raw["id"],
        version: raw["version"],
        api_version: raw["apiVersion"],
        metadata: raw["metadata"] || %{},
        caps: raw["spec"]["caps"],
        model_profile: raw["spec"]["model_profile"],
        stages: stages_ordered,
        stages_by_id: stages_by_id,
        entry_node: entry_id,
        checksum: "pending"
      }

      {:ok, %{base | checksum: compute_checksum(base)}}
    end
  end

  # -- D-62 validators -----------------------------------------------------

  # D-62 validator 6: signature must be null in v1 (D-65 reservation).
  defp validate_signature_null(%{"signature" => nil}), do: :ok

  defp validate_signature_null(%{"signature" => other}) do
    {:error, {:graph_invalid, :signature_must_be_null, %{signature: other}}}
  end

  # Key absent: treated as null-equivalent. JSV schema requires signature
  # be present, so this branch only runs via the direct compile/1 entry
  # point (tests).
  defp validate_signature_null(_), do: :ok

  defp fetch_stages(%{"spec" => %{"stages" => stages}}) when is_list(stages) do
    {:ok, stages}
  end

  defp fetch_stages(_) do
    {:error, {:graph_invalid, :no_entry_node, %{reason: "missing spec.stages"}}}
  end

  defp normalize_stages(stages_raw) do
    normalized =
      Enum.map(stages_raw, fn s ->
        %{
          id: s["id"],
          kind: Map.fetch!(@kind_atoms, s["kind"]),
          agent_role: Map.fetch!(@agent_role_atoms, s["agent_role"]),
          depends_on: s["depends_on"] || [],
          timeout_seconds: s["timeout_seconds"],
          retry_policy: s["retry_policy"],
          sandbox: Map.fetch!(@sandbox_atoms, s["sandbox"]),
          model_preference: s["model_preference"],
          on_failure: normalize_on_failure(s["on_failure"])
        }
      end)

    {:ok, normalized}
  end

  defp normalize_on_failure(nil), do: nil
  defp normalize_on_failure("escalate"), do: :escalate

  defp normalize_on_failure(%{"action" => "route", "to" => to, "attach" => attach}) do
    %{action: :route, to: to, attach: attach}
  end

  # D-62 validator 1: exactly one stage has `depends_on: []` (entry node).
  defp validate_single_entry(stages) do
    entry_count = Enum.count(stages, fn s -> s.depends_on == [] end)

    cond do
      entry_count == 0 ->
        {:error, {:graph_invalid, :no_entry_node, %{}}}

      entry_count > 1 ->
        {:error, {:graph_invalid, :multiple_entry_nodes, %{count: entry_count}}}

      true ->
        :ok
    end
  end

  # D-62 validator 5: every `kind` has a matching contract under
  # priv/stage_contracts/v1/.
  defp validate_all_kinds_have_contracts(stages) do
    case Enum.find(stages, fn s ->
           case ContractRegistry.fetch(s.kind) do
             {:ok, _} -> false
             _ -> true
           end
         end) do
      nil ->
        :ok

      s ->
        {:error, {:graph_invalid, {:unknown_kind, s.kind}, %{stage_id: s.id, kind: s.kind}}}
    end
  end

  # D-62 validators 2 + 3 combined: topological sort + missing-dep detection.
  defp topological_sort(stages) do
    case Graph.topological_sort(stages) do
      {:ok, _} = ok ->
        ok

      {:error, :cycle} ->
        {:error, {:graph_invalid, :cycle, %{}}}

      {:error, {:missing_dep, dep}} ->
        {:error, {:graph_invalid, {:missing_dep, dep}, %{missing: dep}}}
    end
  end

  # D-62 validator 4: every on_failure.to must be a STRICT topological
  # ancestor of the from-stage. A parallel sibling (equal position by
  # id) is also rejected — strict-less-than is the only valid ancestor
  # relation (threat T3).
  defp validate_on_failure_ancestors(stages, sorted_ids) do
    pos = sorted_ids |> Enum.with_index() |> Map.new()

    offender =
      Enum.find(stages, fn s ->
        case s.on_failure do
          %{to: to_id} -> Map.get(pos, to_id, -1) >= Map.get(pos, s.id, -1)
          _ -> false
        end
      end)

    case offender do
      nil ->
        :ok

      s ->
        {:error, {:graph_invalid, :on_failure_forward_edge, %{from: s.id, to: s.on_failure.to}}}
    end
  end

  defp find_entry(stages) do
    case Enum.find(stages, fn s -> s.depends_on == [] end) do
      nil -> {:error, {:graph_invalid, :no_entry_node, %{}}}
      s -> {:ok, s.id}
    end
  end

  # -- Checksum ------------------------------------------------------------

  defp compute_checksum(%CompiledGraph{} = g) do
    term =
      {g.id, g.version, g.api_version, g.model_profile, g.caps,
       normalize_stages_for_hash(g.stages)}

    bin = :erlang.term_to_binary(term, [:deterministic])
    :crypto.hash(:sha256, bin) |> Base.encode16(case: :lower)
  end

  defp normalize_stages_for_hash(stages) do
    Enum.map(stages, fn s ->
      {s.id, s.kind, s.agent_role, s.depends_on, s.timeout_seconds, s.retry_policy, s.sandbox,
       s.model_preference, s.on_failure}
    end)
  end
end
