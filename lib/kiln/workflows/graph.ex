defmodule Kiln.Workflows.Graph do
  @moduledoc """
  `:digraph`-based topological sort + cycle detection for workflow stages
  (D-62 validator 2).

  Uses the OTP stdlib `:digraph` with the `:acyclic` creation flag so
  `:digraph.add_edge/3` returns `{:error, {:bad_edge, path}}` the moment
  a cycle would be introduced — no separate `is_acyclic/1` call needed.

  Missing-dep detection is performed separately by checking each edge's
  target against the set of known stage ids before the edge is added, so
  callers can distinguish `{:error, {:missing_dep, id}}` from
  `{:error, :cycle}`.

  ## ETS hygiene

  `:digraph` tables are backed by ETS and are NOT garbage-collected when
  the reference goes out of scope. Every code path MUST call
  `:digraph.delete/1` or each call leaks a table — after 1000 iterations
  the VM's ETS limit is hit and `:digraph.new/1` crashes with
  `:system_limit`. This module uses `try/after :digraph.delete/1` for
  that reason. The regression test in
  `test/kiln/workflows/graph_test.exs` iterates 1000 times and asserts
  `length(:ets.all())` did not grow meaningfully — enforced structurally.

  ## Return shape

  Returns `{:ok, [String.t()]}` with a valid topological order on
  success; `{:error, :cycle}` or `{:error, {:missing_dep, String.t()}}`
  on failure. Empty input returns `{:ok, []}`.
  """

  @type stage_like :: %{
          required(:id) => String.t(),
          required(:depends_on) => [String.t()],
          optional(atom()) => term()
        }

  @spec topological_sort([stage_like()]) ::
          {:ok, [String.t()]}
          | {:error, :cycle | {:missing_dep, String.t()}}
  def topological_sort(stages) when is_list(stages) do
    g = :digraph.new([:acyclic])

    try do
      ids = MapSet.new(stages, & &1.id)

      Enum.each(stages, fn %{id: id} -> :digraph.add_vertex(g, id) end)

      edge_result =
        Enum.reduce_while(stages, :ok, fn %{id: id, depends_on: deps}, :ok ->
          case add_edges_for(g, ids, id, deps) do
            :ok -> {:cont, :ok}
            {:error, _} = err -> {:halt, err}
          end
        end)

      case edge_result do
        :ok ->
          case :digraph_utils.topsort(g) do
            false -> {:error, :cycle}
            sorted when is_list(sorted) -> {:ok, sorted}
          end

        {:error, _} = err ->
          err
      end
    after
      # MANDATORY: ETS-backed resource. Skipping this leaks one table
      # per call; the :system_limit crash is a common beginner bug.
      :digraph.delete(g)
    end
  end

  # -- private -------------------------------------------------------------

  defp add_edges_for(g, known_ids, id, deps) do
    Enum.reduce_while(deps, :ok, fn dep, :ok ->
      cond do
        not MapSet.member?(known_ids, dep) ->
          {:halt, {:error, {:missing_dep, dep}}}

        match?({:error, _}, :digraph.add_edge(g, dep, id)) ->
          {:halt, {:error, :cycle}}

        true ->
          {:cont, :ok}
      end
    end)
  end
end
