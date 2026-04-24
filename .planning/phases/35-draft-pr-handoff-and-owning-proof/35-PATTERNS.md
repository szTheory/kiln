# Phase 35: Draft PR handoff and owning proof - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 10
**Primary analogs:** 6

## File Classification

| Likely File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kiln/attach/delivery.ex` | service | transform | `lib/kiln/attach/delivery.ex` | exact |
| `lib/mix/tasks/kiln.attach.prove.ex` | utility | batch | `lib/mix/tasks/kiln.attach.prove.ex`, `lib/mix/tasks/kiln.first_run.prove.ex` | exact |
| `test/integration/github_delivery_test.exs` | test | event-driven | `test/integration/github_delivery_test.exs` | exact |
| `test/mix/tasks/kiln.attach.prove_test.exs` | test | batch | `test/mix/tasks/kiln.attach.prove_test.exs` | exact |
| `test/kiln_web/live/attach_entry_live_test.exs` | test | request-response | `test/kiln_web/live/attach_entry_live_test.exs` | exact |
| `test/kiln/attach/safety_gate_test.exs` | test | request-response | `test/kiln/attach/safety_gate_test.exs` | exact |

## Pattern Assignments

### `lib/kiln/attach/delivery.ex` (service, transform)

**Analog:** `lib/kiln/attach/delivery.ex` [1-212]

**Thin orchestration boundary** ([lines 21-47]):
```elixir
with {:ok, %Run{} = run} <- fetch_run(run_or_id),
     {:ok, %AttachedRepo{} = attached_repo} <- Attach.get_attached_repo(attached_repo_id),
     {:ok, frozen} <- freeze_snapshot(run, attached_repo, runner),
     :ok <- Git.ensure_local_branch(frozen["workspace_path"], frozen["branch"], runner: runner) do
  {:ok,
   %{
     snapshot: frozen_snapshot_fragment(frozen),
     push_args: push_args(run.id, stage_id, frozen),
     pr_args: pr_args(run.id, stage_id, frozen)
   }}
end
```
Copy this shape for Phase 35 changes: gather durable facts, freeze once, then derive worker args from the frozen map. Do not let formatting logic reach into workers directly.

**Snapshot-freeze pattern** ([lines 59-105]):
```elixir
case existing do
  %{"attach" => %{} = attach, "pr" => %{} = pr} ->
    {:ok, %{..., "title" => Map.fetch!(pr, "title"), "body" => Map.fetch!(pr, "body")}}
  _ ->
    create_snapshot(run, attached_repo, runner)
end
```
Phase 35 should preserve this exact trust posture: PR title/body are frozen on `runs.github_delivery_snapshot` and reused on replay.

**Frozen snapshot schema** ([lines 107-129]):
```elixir
"attach" => %{"branch" => ..., "base_branch" => ..., "frozen" => true},
"pr" => %{"title" => ..., "body" => ..., "base" => ..., "head" => ..., "draft" => true, "frozen" => true}
```
If Phase 35 adds proof citations or request framing, add them inside the frozen `pr` payload, not as ephemeral worker-only attrs.

**Current title/body builders** ([lines 184-209]):
```elixir
"draft: #{attached_repo.repo_name}: attached repo update (#{short_run_id(run_id)})"

## Verification
- Attach workspace was marked ready before delivery.
- This PR stays draft-first for operator inspection.

## Kiln context
- Run: `#{run_id}`
- Attached repo: `#{attached_repo.id}`
```
This is the direct Phase 35 replacement seam. Keep it as pure string generation under `Delivery`; do not move wording into `OpenPRWorker`.

**Durable request-field source to pull from**:
- `lib/kiln/attach/intake.ex` [33-43, 46-80] persists `request_kind`, `change_summary`, `acceptance_criteria`, and `out_of_scope`.
- `lib/kiln/specs/spec_draft.ex` [57-61, 98-116] and `lib/kiln/specs/spec_revision.ex` [17-25, 60-82] treat those as durable attached-request facts.

Use those stored fields for `Summary`, `Acceptance criteria`, and conditional `Out of scope`. Do not reuse the rendered markdown body from intake as the visible PR body.

### `lib/kiln/github/open_pr_worker.ex` (worker seam, request-response)

**Analog:** `lib/kiln/github/open_pr_worker.ex` [17-99, 131-139]

**Frozen attrs stay opaque to the worker**:
```elixir
pr_attrs = %{
  "title" => title,
  "body" => body,
  "base" => base,
  "head" => head,
  "draft" => draft,
  "reviewers" => reviewers
}

intent_payload: Map.merge(pr_attrs, %{"frozen" => true})
```
Phase 35 should continue treating the worker as a transport seam. It validates presence, preserves idempotency, and records result payloads. It is not the place to compose PR prose.

### `lib/mix/tasks/kiln.attach.prove.ex` (utility, batch)

**Analogs:** `lib/mix/tasks/kiln.attach.prove.ex` [1-30], `lib/mix/tasks/kiln.first_run.prove.ex` [18-43]

**Current attach-proof pattern**:
```elixir
@proof_layers [
  ["env", "MIX_ENV=test", "mix", "test", "test/integration/github_delivery_test.exs"],
  ["env", "MIX_ENV=test", "mix", "test", "test/kiln/attach/safety_gate_test.exs"],
  ["env", "MIX_ENV=test", "mix", "test", "test/kiln_web/live/attach_entry_live_test.exs"]
]

def run(_args) do
  Enum.each(@proof_layers, &run_cmd/1)
end
```
Phase 35 should extend this list minimally if a new locked proof layer is required for `TRUST-04`/`UAT-06`.

**Similar task precedent from first-run prove**:
```elixir
def run(_args) do
  run_task("integration.first_run", [])
  run_cmd(["env", "MIX_ENV=test", "mix", "test" | @focused_liveview_files])
end
```
Useful copy point: keep the owning task thin, explicit, and delegated. Do not turn docs into the orchestration layer.

### `test/integration/github_delivery_test.exs` (integration test, event-driven)

**Analog:** `test/integration/github_delivery_test.exs` [18-87, 117-187]

**Test setup pattern**:
```elixir
use Kiln.ObanCase, async: false
Application.put_env(:kiln, Kiln.GitHub.PushWorker, git_runner: ...)
Application.put_env(:kiln, Kiln.GitHub.OpenPRWorker, cli_runner: ...)
```
Use env-injected runners and `perform_job/2` rather than shelling out.

**Delivery happy-path lock points**:
```elixir
assert {:ok, prepared} = Attach.enqueue_delivery(...)
assert {:ok, :completed} = perform_job(PushWorker, prepared.push_args)
assert {:ok, :completed} = perform_job(OpenPRWorker, prepared.pr_args)

stored = Repo.get!(Kiln.Runs.Run, run.id).github_delivery_snapshot
assert stored["attach"]["branch"] == prepared.pr_args["head"]
assert stored["pr"]["head"] == prepared.pr_args["head"]
assert stored["pr"]["draft"] == true
```
For Phase 35, this is the best place to lock:
- frozen PR `title` and `body` contents
- proof citation text
- conditional `Out of scope`
- absence of internal-noise fields like naked `attached_repo_id`

**Replay/idempotency pattern** ([lines 89-115]):
```elixir
assert {:ok, :already_done} = perform_job(PushWorker, args)
assert {:ok, :already_done} = perform_job(PushWorker, args)
```
Keep at least one replay assertion whenever body/title freezing changes.

### `test/mix/tasks/kiln.attach.prove_test.exs` (task test, batch)

**Analog:** `test/mix/tasks/kiln.attach.prove_test.exs` [6-80]

**Injection pattern**:
```elixir
Application.put_env(:kiln, :kiln_attach_prove_cmd_runner, fn args ->
  send(parent, {:cmd_run, args})
  :ok
end, persistent: false)
```

**Locked-order assertions**:
```elixir
assert_received {:cmd_run, ["env", "MIX_ENV=test", "mix", "test", "...github_delivery_test.exs"]}
...
refute_received {:cmd_run, _}
```

**Re-run safety**:
```elixir
assert :ok = @task.run([])
assert :ok = @task.run([])
```
If Phase 35 adds a proof layer, update this file first. It is the lock point for the owning proof contract.

### `test/kiln/attach/safety_gate_test.exs` (domain test, request-response)

**Analog:** `test/kiln/attach/safety_gate_test.exs` [6-154]

**Typed readiness/remediation pattern**:
```elixir
assert {:ok, ready} = Attach.preflight_workspace(...)
assert ready.status == :ready

assert {:blocked, blocked} = Attach.preflight_workspace(...)
assert blocked.code == :github_auth_missing
assert blocked.probe == "gh auth status"
assert blocked.next_action == "Run gh auth login ..."
```
Phase 35 should cite this layer as proof of readiness and refusal boundaries, but should not paraphrase this into generic PR reassurance. The reviewer-facing PR text should point to the test layer, not restate all remediation semantics.

### `lib/kiln_web/live/attach_entry_live.ex` + `test/kiln_web/live/attach_entry_live_test.exs` (UI seam + LiveView proof)

**Analogs:** `lib/kiln_web/live/attach_entry_live.ex` [514-600, 1062-1081, 1099-1141, 1193-1270], `test/kiln_web/live/attach_entry_live_test.exs` [420-460, 463-515, 574-586, 625-630]

**Server-authoritative warning seam**:
```elixir
report = evaluate_brownfield_preflight(attached_repo, normalized_request)

cond do
  BrownfieldPreflight.fatal?(report) -> assign_brownfield_blocked(...)
  BrownfieldPreflight.needs_narrowing?(report) -> assign_brownfield_warning(...)
  true -> finalize_attached_request_start(...)
end
```

**Distinct warning render path**:
```elixir
<div id="attach-warning">
<div id="attach-warning-findings">
<button id="attach-narrowing-accept">
<button id="attach-warning-edit">
```

**Focused proof style**:
```elixir
assert has_element?(view, "#attach-warning")
assert has_element?(view, "#attach-warning-findings")
refute_receive {:warning_start_called, _, _}
...
assert has_element?(view, "#attach-run-started")
```
Phase 35 should preserve this boundary split:
- `/attach` owns brownfield warning/narrowing truth
- PR handoff stays compact and does not replay warning sections by default

## Shared Patterns

### Durable Facts, Then Render

**Sources:** `lib/kiln/attach/intake.ex` [33-43], `lib/kiln/specs/spec_draft.ex` [57-61], `lib/kiln/specs/spec_revision.ex` [22-25]

Pattern: attached-request prose shown later should be derived from stored structured fields, not from re-parsed markdown blobs or transient form params.

### Freeze Once, Reuse on Replay

**Source:** `lib/kiln/attach/delivery.ex` [59-129]

Pattern: any new PR-body/title contract belongs inside the frozen GitHub delivery snapshot. This protects replay, worker idempotency, and future proof citations from drift.

### Thin Public Owners

**Sources:** `lib/kiln/attach/delivery.ex` [21-47], `lib/mix/tasks/kiln.attach.prove.ex` [13-30], `lib/kiln_web/live/attach_entry_live.ex` [1193-1270]

Pattern: public seams stay thin and delegate to typed helpers or lower layers. For Phase 35:
- `Delivery` owns PR text assembly and snapshot freezing
- `Mix.Tasks.Kiln.Attach.Prove` owns proof orchestration
- `AttachEntryLive` remains a consumer of attach-side reports and run-start seams

### Proof by Exact Delegated Layers

**Sources:** `lib/mix/tasks/kiln.attach.prove.ex` [13-21], `test/mix/tasks/kiln.attach.prove_test.exs` [23-80]

Pattern: when Kiln says something is proven, it cites the owning command and the exact delegated files. Avoid generic “verified” prose without rerunnable references.

## Likely Plan Split Recommendations

### Split 1: Tighten the frozen PR handoff contract

Use the same backend-first pattern as Phase 31-01 and Phase 33-01:
- Phase 31-01 separated the delivery seam and snapshot freeze from proof ownership in a dedicated backend plan (`31-01-PLAN.md`).
- Phase 33-01 separated the continuity read model from later UX wiring (`33-01-PLAN.md` [95-132]).

Recommended files:
- `lib/kiln/attach/delivery.ex`
- `test/integration/github_delivery_test.exs`
- optionally a focused delivery unit test if the planner wants faster string-shape coverage

Primary locks:
- `Summary` from stored request fields
- `Acceptance criteria`
- conditional `Out of scope`
- exact `Verification` citations
- branch/base facts
- `kiln-run:` footer only

### Split 2: Extend the owning proof command and lock the delegated contract

Mirror Phase 31-02’s “proof owner after backend seam” split (`31-02-PLAN.md` [130-152]).

Recommended files:
- `lib/mix/tasks/kiln.attach.prove.ex`
- `test/mix/tasks/kiln.attach.prove_test.exs`
- whichever proof file gains the minimum new locked layer for `TRUST-04` / `UAT-06`

Primary locks:
- one command remains authoritative
- delegated file order stays explicit
- PR-body verification text and proof-command contract stay in sync

### Split 3: Touch LiveView proof only if Phase 35 wording leaks across boundaries

Use the same “UI alignment last” posture as Phase 34-03 (`34-03-PLAN.md` [106-145]) and Phase 33-03 (`33-03-PLAN.md` [91-126]).

Recommended files only if necessary:
- `test/kiln_web/live/attach_entry_live_test.exs`
- `lib/kiln_web/live/attach_entry_live.ex` only if boundary wording or IDs must move

Reason:
- Phase 35 explicitly should not replay brownfield warning UX into PR text.
- The existing warning and blocked semantics are already well-covered and should remain stable unless a citation or reviewer-facing copy change forces a small adjustment.

## Planner Notes

- Prefer two plans if the proof-layer change is tiny: `Delivery contract` then `Proof owner`.
- Prefer three plans if Phase 35 needs both a new proof layer and a small UI/test boundary update.
- Do not create a plan that centers on `OpenPRWorker`; it is a transport seam, not the composition owner.
- Do not create a plan that dumps full request markdown into PR text; use `Intake`/`SpecDraft`/`SpecRevision` structured fields instead.
- Do not create a plan that adds preflight-warning sections to the PR body by default; the current LiveView warning surface already owns that truth.

## Metadata

**Analog search scope:** `lib/kiln/attach`, `lib/kiln/github`, `lib/mix/tasks`, `lib/kiln_web/live`, `test/integration`, `test/kiln/attach`, `test/kiln_web/live`, nearby phase plans 31/33/34  
**Files scanned:** 14  
**Pattern extraction date:** 2026-04-24
