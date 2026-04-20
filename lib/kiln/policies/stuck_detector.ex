defmodule Kiln.Policies.StuckDetector do
  @moduledoc """
  GenServer hook called from inside `Kiln.Runs.Transitions.transition/3`
  AFTER the row lock (`SELECT ... FOR UPDATE`) and BEFORE the state
  column is updated (D-91). The hook path — Transitions → `check/1` →
  audit trail — IS the Phase 2 behavior being exercised; Phase 5 will
  replace ONLY the `handle_call/3` body with the real sliding-window
  `(stage, failure-class)` logic without touching a single caller.

  D-91 verbatim:

    > `Kiln.Policies.StuckDetector` ships as a real `GenServer` in the
    > Phase 2 supervision tree with a no-op `check/1` body returning `:ok`.
    > NOT a D-42 violation: ROADMAP Phase 2 explicitly lists "P1 stuck-run
    > detector hook point wired" as the phase's behavior-to-exercise. The
    > hook path IS the behavior. `check/1` is called inside
    > `Transitions.transition/3` after the row lock and before the state
    > update — a pre-condition. Phase 5 replaces only the
    > `handle_call({:check, ctx}, ...)` body with sliding-window logic
    > over `(stage, failure-class)` tuples; no caller refactor, no schema
    > migration, no supervisor reshuffle.

  Contract (stable through Phase 5):

      check(ctx :: map()) :: :ok | {:halt, reason :: atom(), payload :: map()}

  A `{:halt, :stuck, payload}` return translates (in `Transitions`) into
  an in-same-tx `transition(run_id, :escalated, payload)`. Firing
  post-commit would let a stuck run ship one more invalid transition
  before being caught — unacceptable for audit clarity.

  Supervision: `:permanent` singleton under `Kiln.Supervisor`
  (Plan 02-07 adds the child spec; this plan only ships the module).
  """

  use GenServer

  @doc """
  Starts the singleton. Intended to be called once from
  `Kiln.Application.start/2` (Plan 02-07); tests that need the detector
  alive should `use Kiln.StuckDetectorCase` which handles the
  start-if-not-started dance and `{:error, {:already_started, _}}`
  tolerance (checker issue #6 mitigation).
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Synchronous hook called from inside `Kiln.Runs.Transitions.transition/3`
  immediately after the `SELECT ... FOR UPDATE` lock on the run row and
  immediately before the `Run.transition_changeset |> Repo.update()`
  step. Returns `:ok` in Phase 2 (no-op body); Phase 5 replaces only the
  `handle_call/3` body to return `{:halt, :stuck, payload}` when a run
  trips the sliding-window threshold.

  Signature is locked through Phase 5 — callers never change.
  """
  @spec check(map()) :: :ok | {:halt, atom(), map()}
  def check(ctx) when is_map(ctx), do: GenServer.call(__MODULE__, {:check, ctx})

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:check, _ctx}, _from, state) do
    # Phase 2: no-op — the hook PATH is the behavior to exercise. Phase 5
    # fills the sliding-window body. Stable return shape:
    #   :ok | {:halt, reason :: atom(), payload :: map()}
    # Callers (Kiln.Runs.Transitions) decode `{:halt, _, _}` as a
    # same-tx transition to `:escalated` with the payload attached to
    # the audit event.
    {:reply, :ok, state}
  end
end
