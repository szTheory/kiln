defmodule Kiln.Agents.BudgetGuard do
  @moduledoc """
  Per-call cost pre-flight (D-138 / AGENT-05). Runs BEFORE every LLM
  call from `Kiln.Stages.StageWorker.perform/1` via the adapter
  behaviour's `before_call` hook (wired in Wave 4/5).

  Strict - no env-var escape hatch (D-138 explicit choice). If the
  operator wants more budget, they edit the workflow caps and restart
  the run. The test suite grep-asserts the literal
  `BUDGET<underscore>OVERRIDE` string never appears anywhere in this
  file, including comments; keep any reference to the rejected pattern
  OUT of this source.

  7-step check order (D-138):

    1. Read `runs.caps_snapshot["max_tokens_usd"]`.
    2. SUM completed-stage spend for the run via `stage_runs.cost_usd`.
    3. Compute `remaining_budget_usd`.
    4. Call `adapter.count_tokens/1` (Anthropic free pre-flight; other
       providers use an estimator per D-138).
    5. `Kiln.Pricing.estimate_usd(model, input_tokens, max_output)`.
    6. Compare estimated to remaining.
    7. Emit `budget_check_passed` OR `budget_check_failed` + raise
       `Kiln.Blockers.BlockedError` with `reason: :budget_exceeded`.

  All 7 steps run inside one telemetry span
  `[:kiln, :agents, :budget_guard, :check]` so the cost-dashboard
  observer (Phase 7) sees a single datum per pre-flight call.

  The prompt argument is accepted as a map (rather than a struct) to
  stay decoupled from `Kiln.Agents.Prompt` (Plan 03-05). The required
  keys on the prompt map are `:model` (or supplied via `opts[:model]`)
  and `:max_tokens`; the adapter's `count_tokens/1` is the source of
  truth for input-token count, so the rest of the prompt shape is
  opaque to this module.
  """

  require Logger

  alias Kiln.Audit
  alias Kiln.Pricing

  @doc """
  Run the 7-step pre-flight against `prompt`. Returns `:ok` on pass;
  raises `Kiln.Blockers.BlockedError` with `reason: :budget_exceeded`
  on breach.

  Required `opts`:
    * `:run_id` - binary UUID of the run being guarded
    * `:stage_id` - binary UUID of the StageRun row being guarded, or
      `nil` when called outside a stage context (test harnesses). The
      `audit_events.stage_id` column is declared as `:binary_id`
      (UUID), so passing a non-UUID string will fail at `Audit.append`
      insertion time. The plan's W8 note inverted this - the schema is
      the UUID, not a workflow-scope string.
    * `:adapter` - module implementing `count_tokens/1`

  Optional:
    * `:model` - overrides `prompt.model` if the prompt map carries
      none (e.g. when called from a pre-Wave-5 test harness)
  """
  @spec check!(map(), keyword()) :: :ok | no_return()
  def check!(prompt, opts) when is_map(prompt) and is_list(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    stage_id = Keyword.fetch!(opts, :stage_id)
    adapter = Keyword.fetch!(opts, :adapter)

    model =
      Map.get(prompt, :model) || Keyword.get(opts, :model) ||
        raise ArgumentError,
              "Kiln.Agents.BudgetGuard.check!/2 requires :model on prompt or opts"

    meta = %{run_id: run_id, stage_id: stage_id, model: model}

    :telemetry.span([:kiln, :agents, :budget_guard, :check], meta, fn ->
      result = do_check(prompt, run_id, stage_id, model, adapter)
      {result, meta}
    end)
  end

  defp do_check(prompt, run_id, stage_id, model, adapter) do
    run = Kiln.Runs.get!(run_id)
    cap = decimalize(get_in(run.caps_snapshot, ["max_tokens_usd"]) || 0)
    spent = sum_stage_spend(run_id)
    remaining = Decimal.sub(cap, spent)

    {:ok, tokens_in} = adapter.count_tokens(prompt)

    estimated_output = Map.get(prompt, :max_tokens) || 0
    estimated = Pricing.estimate_usd(model, tokens_in, estimated_output)
    breach? = Decimal.compare(estimated, remaining) == :gt

    correlation_id = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

    if breach? do
      _ =
        Audit.append(%{
          event_kind: :budget_check_failed,
          run_id: run_id,
          stage_id: stage_id,
          correlation_id: correlation_id,
          payload: %{
            "estimated_usd" => Decimal.to_string(estimated),
            "remaining_usd" => Decimal.to_string(remaining),
            "cap_usd" => Decimal.to_string(cap),
            "spent_usd" => Decimal.to_string(spent),
            "model" => model,
            "tokens_in" => tokens_in,
            "tokens_out" => estimated_output
          }
        })

      _ =
        maybe_notify(:budget_exceeded, %{
          run_id: run_id,
          estimated_usd: Decimal.to_string(estimated),
          remaining_usd: Decimal.to_string(remaining),
          severity: "halt"
        })

      raise Kiln.Blockers.BlockedError,
        reason: :budget_exceeded,
        run_id: run_id,
        context: %{
          estimated_usd: Decimal.to_string(estimated),
          remaining_usd: Decimal.to_string(remaining),
          model: model
        }
    else
      _ =
        Audit.append(%{
          event_kind: :budget_check_passed,
          run_id: run_id,
          stage_id: stage_id,
          correlation_id: correlation_id,
          payload: %{
            "estimated_usd" => Decimal.to_string(estimated),
            "remaining_usd" => Decimal.to_string(remaining),
            "cap_usd" => Decimal.to_string(cap),
            "spent_usd" => Decimal.to_string(spent),
            "model" => model,
            "tokens_in" => tokens_in,
            "tokens_out" => estimated_output
          }
        })

      :ok
    end
  end

  defp sum_stage_spend(run_id) do
    import Ecto.Query

    result =
      Kiln.Repo.one(
        from sr in Kiln.Stages.StageRun,
          where: sr.run_id == ^run_id and sr.state in [:succeeded, :failed],
          select: sum(sr.cost_usd)
      )

    case result do
      nil -> Decimal.new(0)
      %Decimal{} = d -> d
      other when is_integer(other) or is_float(other) -> decimalize(other)
    end
  end

  defp maybe_notify(reason, ctx) do
    if Code.ensure_loaded?(Kiln.Notifications) and
         function_exported?(Kiln.Notifications, :desktop, 2) and
         :ets.whereis(Kiln.Notifications.DedupCache) != :undefined do
      apply(Kiln.Notifications, :desktop, [reason, ctx])
    else
      :ok
    end
  end

  defp decimalize(%Decimal{} = d), do: d
  defp decimalize(s) when is_binary(s), do: Decimal.new(s)
  defp decimalize(n) when is_integer(n), do: Decimal.new(n)
  defp decimalize(n) when is_float(n), do: Decimal.from_float(n)
end
