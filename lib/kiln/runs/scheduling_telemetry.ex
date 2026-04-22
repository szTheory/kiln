defmodule Kiln.Runs.SchedulingTelemetry do
  @moduledoc """
  PARA-01 / D-11 — dwell telemetry for runs leaving `:queued`.

  Emits **one** `:telemetry.execute/3` per successful transition out of
  `:queued` (first departure only in v1 — the D-87 matrix has no edge
  back to `:queued`).

  ## Measurement

  * **`duration`** — integer **milliseconds** of wall-clock time from
    `run.inserted_at` to the transition commit instant (`DateTime.utc_now/0`).
    This is **not** monotonic time; clock skew can theoretically produce
    `0` after `max/2` clamping.

  ## Metadata (whitelist)

  * **`run_id`** — string UUID
  * **`next_state`** — string target state
  * **`correlation_id`** — from the run row, or `\"none\"` when absent

  ## Metrics cardinality (D-11)

  Do **not** add `run_id` (or this event's metadata keys) as **Prometheus /
  `Telemetry.Metrics` summary tags** in `KilnWeb.Telemetry` — per-run labels
  explode cardinality. PARA-01 v1 is **event-first**; aggregate metrics belong
  in a later phase if needed.
  """

  alias Kiln.Runs.Run

  @event [:kiln, :run, :scheduling, :queued, :stop]

  @doc """
  Emits `[:kiln, :run, :scheduling, :queued, :stop]` when `run` is still `:queued`.

  Idempotent for callers transitioning from other states: returns `:ok`
  without executing when `run.state != :queued`.
  """
  @spec emit_queued_dwell_stop(Run.t(), atom()) :: :ok
  def emit_queued_dwell_stop(%Run{} = run, to_state) when is_atom(to_state) do
    if run.state != :queued do
      :ok
    else
      duration_ms =
        DateTime.diff(DateTime.utc_now(), run.inserted_at, :millisecond)
        |> max(0)

      corr =
        case run.correlation_id do
          c when is_binary(c) and c != "" -> c
          _ -> "none"
        end

      :telemetry.execute(
        @event,
        %{duration: duration_ms},
        %{
          run_id: to_string(run.id),
          next_state: Atom.to_string(to_state),
          correlation_id: corr
        }
      )

      :ok
    end
  end
end
