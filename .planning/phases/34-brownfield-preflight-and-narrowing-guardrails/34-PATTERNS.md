# Phase 34: Brownfield preflight and narrowing guardrails - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 8 likely target files
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kiln/attach/brownfield_preflight.ex` | service/read model + evaluator | request-response | `lib/kiln/attach/continuity.ex`, `lib/kiln/attach/safety_gate.ex` | role-match |
| `lib/kiln/attach.ex` | public boundary | request-response | `lib/kiln/attach.ex` | exact |
| `lib/kiln/specs.ex` | context query | request-response | `lib/kiln/specs.ex` | exact |
| `lib/kiln/runs.ex` | context query/start seam | request-response | `lib/kiln/runs.ex` | exact |
| `lib/kiln_web/live/attach_entry_live.ex` | LiveView | SSR + events | `lib/kiln_web/live/attach_entry_live.ex` | exact |
| `test/kiln/attach/brownfield_preflight_test.exs` | service test | request-response | `test/kiln/attach/continuity_test.exs`, `test/kiln/attach/safety_gate_test.exs` | role-match |
| `test/kiln/runs/attached_request_start_test.exs` | context test | request-response | `test/kiln/runs/attached_request_start_test.exs` | exact |
| `test/kiln_web/live/attach_entry_live_test.exs` | LiveView test | request-response | `test/kiln_web/live/attach_entry_live_test.exs` | exact |

## Pattern Assignments

### `lib/kiln/attach/brownfield_preflight.ex` (service/read model + evaluator, request-response)

**Primary analogs:** `lib/kiln/attach/continuity.ex`, `lib/kiln/attach/safety_gate.ex`

**Imports and boundary shape to copy**

- Copy the narrow context boundary and local aliases from [lib/kiln/attach/continuity.ex](/Users/jon/projects/kiln/lib/kiln/attach/continuity.ex:6) and [lib/kiln/attach/safety_gate.ex](/Users/jon/projects/kiln/lib/kiln/attach/safety_gate.ex:6).
- Keep the evaluator under `Kiln.Attach`, not in `Kiln.Runs` or the LiveView.

**Typed result pattern to copy**

From [lib/kiln/attach/safety_gate.ex](/Users/jon/projects/kiln/lib/kiln/attach/safety_gate.ex:11):

```elixir
@type ready :: %{status: :ready, ...}
@type blocked :: %{status: :blocked, code: blocked_code(), ...}
@type result :: {:ok, ready()} | {:blocked, blocked()}
```

For Phase 34, mirror this style with a typed advisory report rather than ad hoc maps. Use explicit finding codes, severities, evidence, and next actions. Keep tuple-level blocking only for deterministic fatal conditions.

**Read-model assembly pattern to copy**

From [lib/kiln/attach/continuity.ex](/Users/jon/projects/kiln/lib/kiln/attach/continuity.ex:95):

```elixir
case Repo.get(AttachedRepo, attached_repo_id) do
  nil ->
    {:error, :not_found}

  %AttachedRepo{} = attached_repo ->
    last_run = latest_run(attached_repo_id)
    last_request = latest_request_target(attached_repo_id)
    selected_target = selected_target(attached_repo_id, opts, last_request)

    {:ok,
     %{
       attached_repo: attached_repo,
       last_run: last_run && run_context(last_run),
       last_request: last_request,
       selected_target: selected_target,
       carry_forward: carry_forward(selected_target)
     }}
end
```

Phase 34 should follow this pattern: load one authoritative attached repo, fetch a bounded same-repo candidate set, then shape a report once. Keep the heuristic evaluator pure over already-fetched facts where possible.

**Same-repo candidate precedence and bounded scope to copy**

- Use same-repo-only filtering like [lib/kiln/specs.ex](/Users/jon/projects/kiln/lib/kiln/specs.ex:40) and [lib/kiln/runs.ex](/Users/jon/projects/kiln/lib/kiln/runs.ex:354) for every candidate query.
- Reuse delivery snapshot fields as evidence, not as durable truth, like [lib/kiln/attach/continuity.ex](/Users/jon/projects/kiln/lib/kiln/attach/continuity.ex:267) and [lib/kiln/attach/delivery.ex](/Users/jon/projects/kiln/lib/kiln/attach/delivery.ex:107).

**Rules to copy**

- Deterministic facts first, heuristics second.
- Return one shaped report struct/map from the context; do not leak raw Ecto rows into the LiveView.
- Keep severity typed: `:fatal`, `:warning`, `:info`.
- Keep overlap classes typed and narrow: `:possible_duplicate`, `:possible_overlap`.

**Rules to avoid**

- Do not put fuzzy overlap logic into `Kiln.Attach.SafetyGate`.
- Do not persist a durable ready/safe verdict on `attached_repos`.
- Do not infer cross-repo overlap.
- Do not let the UI compute matching or severity.

### `lib/kiln/attach.ex` (public boundary, request-response)

**Primary analog:** `lib/kiln/attach.ex`

**Public delegation pattern to copy**

From [lib/kiln/attach.ex](/Users/jon/projects/kiln/lib/kiln/attach.ex:63):

```elixir
@spec preflight_workspace(Source.t(), WorkspaceManager.result(), keyword()) ::
        preflight_result()
def preflight_workspace(%Source{} = source, %WorkspaceManager{} = hydrated, opts \\ []) do
  SafetyGate.evaluate(source, hydrated, opts)
end
```

And from [lib/kiln/attach.ex](/Users/jon/projects/kiln/lib/kiln/attach.ex:91):

```elixir
@spec get_repo_continuity(Ecto.UUID.t(), keyword()) :: continuity_result()
def get_repo_continuity(attached_repo_id, opts \\ []) when is_binary(attached_repo_id) do
  Continuity.get_repo_continuity(attached_repo_id, opts)
end
```

Phase 34 should add one or two thin public entry points here for brownfield preflight, rather than teaching callers about an internal advisory module directly.

**Rules to copy**

- Keep `Attach` as the only public seam consumed by `/attach`.
- Add types at the boundary.
- Preserve the split between deterministic preflight (`preflight_workspace`) and advisory preflight.

**Rules to avoid**

- Do not fold advisory evaluation into `refresh_attached_repo/2` if the UI needs the full report separately.
- Do not make `Attach` itself own query composition or scoring internals.

### `lib/kiln/specs.ex` (context query, request-response)

**Primary analog:** `lib/kiln/specs.ex`

**Bounded same-repo query pattern to copy**

From [lib/kiln/specs.ex](/Users/jon/projects/kiln/lib/kiln/specs.ex:40):

```elixir
from(d in SpecDraft,
  where:
    d.id == ^draft_id and d.attached_repo_id == ^attached_repo_id and
      d.source == :attached_repo_intake and d.inbox_state == :open
)
|> Repo.one()
```

From [lib/kiln/specs.ex](/Users/jon/projects/kiln/lib/kiln/specs.ex:51):

```elixir
from(d in SpecDraft,
  where:
    d.attached_repo_id == ^attached_repo_id and d.source == :attached_repo_intake and
      d.inbox_state == :open,
  order_by: [desc: d.inserted_at],
  limit: 1
)
|> Repo.one()
```

Phase 34 should follow this exact same-repo filtering style for open drafts and recent promoted requests. If extra brownfield candidate queries are needed, add them here or in a dedicated attach-owned read model, but keep them bounded by `attached_repo_id`.

**Rules to copy**

- Query with explicit `attached_repo_id`.
- Filter by explicit state/source, not by body parsing.
- Keep ordering and limits in SQL, not post-processed in LiveView.

**Rules to avoid**

- Do not widen candidate pools to all specs or all repos.
- Do not recover overlap meaning from markdown when structured fields already exist.

### `lib/kiln/runs.ex` (context query/start seam, request-response)

**Primary analog:** `lib/kiln/runs.ex`

**Typed preflight/start seam to copy**

From [lib/kiln/runs.ex](/Users/jon/projects/kiln/lib/kiln/runs.ex:166):

```elixir
@spec preflight_attached_request_start() ::
        :ok | {:blocked, template_start_blocked()} | {:error, :missing_api_key}
def preflight_attached_request_start do
  case OperatorSetup.first_blocker() do
    nil ->
      case attached_request_missing_provider_keys() do
        [] -> :ok
        _missing -> {:error, :missing_api_key}
      end

    blocker ->
      {:blocked, blocked_start(blocker, nil, [])}
  end
end
```

Phase 34 should preserve this exact seam discipline. Brownfield advisory findings can influence attach UX, but `Runs.start_for_attached_request/3` should remain the final deterministic start authority for operator setup and provider-key blockers.

**Same-repo run lookup pattern to copy**

From [lib/kiln/runs.ex](/Users/jon/projects/kiln/lib/kiln/runs.ex:354):

```elixir
from(r in Run,
  where: r.id == ^run_id and r.attached_repo_id == ^attached_repo_id,
  ...
)
|> Repo.one()
```

Use this pattern for any brownfield lookup that needs recent same-repo runs or exact in-flight lane checks.

**Rules to copy**

- Keep typed `{:blocked, ...}` returns for hard blockers only.
- Keep run start cleanup behavior intact when a queued run cannot start.
- Keep attach identity explicit on the run row and in any lane-collision checks.

**Rules to avoid**

- Do not move advisory heuristics into `Runs`.
- Do not let a warning-only overlap finding hard-fail start on its own in Phase 34.

### `lib/kiln_web/live/attach_entry_live.ex` (LiveView, SSR + events)

**Primary analog:** `lib/kiln_web/live/attach_entry_live.ex`

**State-driven rendering pattern to copy**

From [lib/kiln_web/live/attach_entry_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/attach_entry_live.ex:289):

```heex
<% :ready -> %>
  <div id="attach-ready" class="space-y-4">
    ...
  </div>
<% :continuity -> %>
  <div id="attach-continuity" class="space-y-4">
    ...
  </div>
<% :blocked -> %>
  <div id="attach-blocked" class="space-y-4">
    ...
  </div>
```

Phase 34 should add a distinct warning/narrowing branch in this same style. Do not overload `:blocked` or hide advisory findings in `@request_error`.

**Server-authoritative attach flow to copy**

From [lib/kiln_web/live/attach_entry_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/attach_entry_live.ex:778):

```elixir
with {:ok, hydrated} <- Attach.hydrate_workspace(resolved_source, opts),
     {:ok, attached_repo} <- create_or_update_attached_repo(resolved_source, hydrated),
     {:ok, ready} <- Attach.preflight_workspace(resolved_source, hydrated, opts) do
  ...
else
  {:blocked, blocked} -> ...
end
```

Phase 34 should extend this chain by evaluating advisory preflight after hard safety passes. Keep the order deterministic: resolve -> hydrate -> persist -> hard gate -> advisory report -> render.

**Route-backed continuity pattern to copy**

From [lib/kiln_web/live/attach_entry_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/attach_entry_live.ex:1109):

```elixir
case get_repo_continuity(attached_repo_id, continuity_opts) do
  {:ok, continuity} ->
    _ = mark_repo_selected(attached_repo_id)
    ...
    |> assign(:resolution_state, :continuity)
    |> assign(:continuity, continuity)
```

If Phase 34 exposes an inspect action for prior draft/run/PR evidence, keep it route-backed and same-repo-scoped like continuity.

**Rules to copy**

- Stable ids for every new warning/narrowing panel, CTA, and inspect target.
- Thin LiveView: assign a report, render a branch, post events back.
- Preserve existing `Layouts.app` wrapper and current-scope plumbing.
- Keep one obvious primary CTA and one explicit secondary edit path.

**Rules to avoid**

- Do not compute overlap tokens or severity in the template or hook.
- Do not collapse warning/narrowing into the blocked styling.
- Do not silently bypass a warning state straight into run start.

### `test/kiln/attach/brownfield_preflight_test.exs` (service test, request-response)

**Primary analogs:** `test/kiln/attach/safety_gate_test.exs`, `test/kiln/attach/continuity_test.exs`

**Deterministic fixture pattern to copy**

From [test/kiln/attach/safety_gate_test.exs](/Users/jon/projects/kiln/test/kiln/attach/safety_gate_test.exs:6):

```elixir
describe "preflight_workspace/3" do
  test "returns ready metadata ..." do
    ...
    assert {:ok, ready} = Attach.preflight_workspace(source, hydrated, ...)
    assert ready.status == :ready
  end
end
```

**Same-repo candidate and precedence pattern to copy**

From [test/kiln/attach/continuity_test.exs](/Users/jon/projects/kiln/test/kiln/attach/continuity_test.exs:49):

```elixir
assert {:ok, _other_draft} = Intake.create_draft(other_repo.id, ...)
assert {:ok, continuity} = Attach.get_repo_continuity(attached_repo.id)
assert continuity.selected_target.source_id == open_draft.id
```

Phase 34 tests should keep slices small and deterministic:

- one file for advisory report shaping
- one test per finding class
- explicit proof that cross-repo data is ignored
- explicit proof that warning findings do not become fatal without deterministic evidence

**Rules to avoid**

- Do not write giant integration-style attach tests here.
- Do not assert on vague prose only; assert codes, severities, and evidence fields.

### `test/kiln/runs/attached_request_start_test.exs` (context test, request-response)

**Primary analog:** `test/kiln/runs/attached_request_start_test.exs`

**Typed blocked-start regression pattern to copy**

From [test/kiln/runs/attached_request_start_test.exs](/Users/jon/projects/kiln/test/kiln/runs/attached_request_start_test.exs:37):

```elixir
assert {:blocked,
        %{
          reason: :factory_not_ready,
          blocker: %{id: :anthropic, href: "/settings#settings-item-anthropic"},
          settings_target: "/settings?return_to=%2Fattach#settings-item-anthropic"
        }} =
       Runs.start_for_attached_request(promoted_request, attached_repo.id,
         return_to: "/attach"
       )
```

Phase 34 should add regressions only where advisory guardrails interact with run-start boundaries. The invariant is that hard start blockers stay typed and deterministic.

**Rules to avoid**

- Do not move advisory coverage into this test file unless it affects `Runs` behavior directly.
- Do not test LiveView warning copy here.

### `test/kiln_web/live/attach_entry_live_test.exs` (LiveView test, request-response)

**Primary analog:** `test/kiln_web/live/attach_entry_live_test.exs`

**Stable-id rendering proof pattern to copy**

From [test/kiln_web/live/attach_entry_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/attach_entry_live_test.exs:20):

```elixir
assert has_element?(view, "#attach-entry-root")
assert has_element?(view, "#attach-source-form")
assert has_element?(view, "#attach-source-untouched")
```

**Route-backed continuity proof pattern to copy**

From [test/kiln_web/live/attach_entry_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/attach_entry_live_test.exs:58):

```elixir
{:ok, view, _html} = live(conn, ~p"/attach?attached_repo_id=#{attached_repo.id}")
assert_receive {:continuity_loaded, ^attached_repo_id, []}
assert has_element?(view, "#attach-continuity")
```

**Refresh-before-launch proof pattern to copy**

From [test/kiln_web/live/attach_entry_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/attach_entry_live_test.exs:126):

```elixir
assert_receive {:refresh_called, ^attached_repo_id}
assert_receive {:start_called, %{spec: %Spec{id: "spec-123"}, revision: %SpecRevision{id: "rev-123"}}, ^refreshed_repo_id}
```

Phase 34 should follow the same runtime-injection testing style for warning/narrowing:

- inject a brownfield-preflight function through `:attach_live_runtime_opts`
- assert the correct state branch renders
- assert primary CTA chooses the suggested narrowed request
- assert manual edit path remains available
- assert inspect CTA is route-backed and same-repo-scoped

**Rules to avoid**

- Do not assert against full-page raw HTML when `has_element?/2` or `element/2` is enough.
- Do not bury warning coverage inside ready-state tests; add separate slices.

## Shared Patterns

### Deterministic Safety Gate Boundary

**Source:** [lib/kiln/attach/safety_gate.ex](/Users/jon/projects/kiln/lib/kiln/attach/safety_gate.ex:46)

```elixir
with :ok <- ensure_clean_repo(source, hydrated, opts),
     :ok <- ensure_attached_workspace_ready(hydrated, opts),
     {:ok, remote} <- ensure_github_remote(source, hydrated, opts),
     :ok <- ensure_github_auth(hydrated, opts) do
  {:ok, %{status: :ready, ...}}
end
```

Apply to all Phase 34 work: hard mutation blockers stay here or follow this pattern. Advisory preflight must run only after this boundary passes.

### Advisory Read-Model Boundary

**Source:** [lib/kiln/attach/continuity.ex](/Users/jon/projects/kiln/lib/kiln/attach/continuity.ex:101)

```elixir
last_run = latest_run(attached_repo_id)
last_request = latest_request_target(attached_repo_id)
selected_target = selected_target(attached_repo_id, opts, last_request)
```

Apply to the new brownfield preflight: fetch bounded same-repo candidates first, then evaluate. Keep evidence relational and explicit.

### Delivery Snapshot Evidence Boundary

**Sources:** [lib/kiln/attach/delivery.ex](/Users/jon/projects/kiln/lib/kiln/attach/delivery.ex:107), [lib/kiln/attach/continuity.ex](/Users/jon/projects/kiln/lib/kiln/attach/continuity.ex:267)

```elixir
"attach" => %{
  "attached_repo_id" => ...,
  "repo_slug" => ...,
  "base_branch" => ...,
  "branch" => ...
}
```

Use snapshots as advisory evidence for in-flight lane warnings. Do not treat them as the primary system of record over `attached_repo_id`, `spec_id`, `spec_revision_id`, or `run_id`.

### Operator Remediation Vocabulary

**Source:** [lib/kiln/operator_setup.ex](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:60)

```elixir
%{
  id: :github,
  title: "GitHub CLI authentication",
  next_action: "Run gh auth login (or equivalent) on this machine, then re-verify.",
  href: "/settings#settings-item-github",
  probe: "gh auth status"
}
```

Use the same calm, factual remediation style for fatal findings. Warning copy should stay advisory, not dramatic.

### Attach LiveView Runtime Injection

**Source:** [lib/kiln_web/live/attach_entry_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/attach_entry_live.ex:974)

```elixir
fun =
  Keyword.get(
    attach_runtime_opts(),
    :create_or_update_attached_repo_fn,
    &Attach.create_or_update_attached_repo/2
  )
```

Use this exact seam for brownfield advisory tests instead of mocking internals globally.

## Test Slices

- `test/kiln/attach/brownfield_preflight_test.exs`: fatal deterministic collision facts vs warning-only overlap facts.
- `test/kiln/attach/brownfield_preflight_test.exs`: same-repo-only candidate filtering, recent-run weighting, delivery snapshot evidence shaping.
- `test/kiln_web/live/attach_entry_live_test.exs`: new narrowing state renders with stable ids and distinct visual semantics from blocked.
- `test/kiln_web/live/attach_entry_live_test.exs`: primary CTA accepts Kiln’s suggested narrower request; secondary CTA keeps manual edit.
- `test/kiln_web/live/attach_entry_live_test.exs`: inspect action points at one prior same-repo draft/run/PR evidence object.
- `test/kiln/runs/attached_request_start_test.exs`: advisory findings do not weaken existing deterministic start blockers.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| None | — | — | Phase 34 can be built by combining existing safety-gate, continuity, delivery-snapshot, and attach LiveView patterns. |

## Metadata

**Analog search scope:** `lib/kiln/attach*`, `lib/kiln/runs.ex`, `lib/kiln/specs.ex`, `lib/kiln/operator_setup.ex`, `lib/kiln_web/live/attach_entry_live.ex`, matching tests

**Files scanned:** 14

**Pattern extraction date:** 2026-04-24
