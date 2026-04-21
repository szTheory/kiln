defmodule Kiln.GitHub.Promoter do
  @moduledoc """
  Applies GitHub **check observation** outcomes to durable run state.

  * Updates `github_delivery_snapshot` via `Kiln.Runs.promote_github_snapshot/2`.
  * Appends `:ci_status_observed` audit (JSV payload) for terminal outcomes.
  * Drives `Kiln.Runs.Transitions.transition/3` when the run is `:verifying`:

      * audit `status: "success"` → `:merged` (`:github_checks_passed`)
      * audit `status: "failure"` → `:planning` (`:github_checks_failed`) with
        `diagnostic` persisted on the run via `escalation_detail`.
  """

  alias Kiln.{Audit, Runs}
  alias Kiln.Runs.Transitions

  require Logger

  @doc """
  `summary_map` uses **string keys** such as `"predicate_pass"`, `"is_draft"`,
  `"head_sha"`, `"required_failed"`, and `"required"` (list of check maps).
  """
  @spec apply_check_result(Ecto.UUID.t(), map()) ::
          {:ok, :ignored | Kiln.Runs.Run.t()} | {:error, term()}
  def apply_check_result(run_id, summary_map) when is_map(summary_map) do
    sm = stringify_keys(summary_map)

    case Runs.get(run_id) do
      nil ->
        {:error, :not_found}

      %{state: :verifying} = run ->
        do_apply(run, sm)

      _ ->
        {:ok, :ignored}
    end
  end

  defp do_apply(run, sm) do
    ts = DateTime.utc_now() |> DateTime.to_iso8601()

    snap = %{
      "checks" => Map.drop(sm, ["updated_at"]),
      "predicate_pass" => Map.get(sm, "predicate_pass"),
      "updated_at" => ts
    }

    status = audit_status(sm)

    with {:ok, _} <- Runs.promote_github_snapshot(run.id, snap),
         {:ok, _} <- maybe_append_audit(run.id, status, sm) do
      route_transition(run.id, sm, status)
    end
  end

  defp stringify_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} when is_binary(k) -> {k, v}
    end)
  end

  defp audit_status(%{"required_failed" => true}), do: "failure"
  defp audit_status(%{"predicate_pass" => true, "is_draft" => true}), do: "failure"
  defp audit_status(%{"predicate_pass" => true}), do: "success"
  defp audit_status(_), do: "pending"

  defp maybe_append_audit(_run_id, "pending", _sm), do: {:ok, :skip}

  defp maybe_append_audit(run_id, status, sm) do
    cid = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

    Audit.append(%{
      event_kind: :ci_status_observed,
      run_id: run_id,
      correlation_id: cid,
      payload: %{
        "status" => status,
        "predicate_pass" => Map.get(sm, "predicate_pass", false),
        "head_sha" => Map.get(sm, "head_sha", "")
      }
    })
  end

  defp route_transition(run_id, _sm, "success") do
    Transitions.transition(run_id, :merged, %{reason: :github_checks_passed})
  end

  defp route_transition(run_id, sm, "failure") do
    diagnostic = diagnostic_from(sm)

    Transitions.transition(run_id, :planning, %{
      reason: :github_checks_failed,
      diagnostic: diagnostic
    })
  end

  defp route_transition(_run_id, _sm, _), do: {:ok, :ignored}

  defp diagnostic_from(sm) do
    rows = List.wrap(Map.get(sm, "required", []))

    %{
      "checks" =>
        Enum.map(rows, fn row ->
          row = stringify_keys(row)

          %{
            "name" => Map.get(row, "name"),
            "conclusion" => Map.get(row, "conclusion")
          }
        end)
    }
  end
end
