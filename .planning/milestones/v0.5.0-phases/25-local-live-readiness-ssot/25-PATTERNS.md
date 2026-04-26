# Phase 25: local-live-readiness-ssot - Pattern Map

**Mapped:** 2026-04-23
**Scope:** Operator-facing readiness/disconnected-state UI, LiveView test conventions for those surfaces, and recent verification/summary artifact style
**Phase artifacts read:** `25-CONTEXT.md`, `25-RESEARCH.md`, plus the existing codebase and recent phase artifacts.

## File Classification

| Likely Phase 25 Surface | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kiln/operator_setup.ex` style SSOT logic | service | transform | `lib/kiln/operator_setup.ex` | exact |
| Shared operator chrome readiness strip/banner | component | request-response | `lib/kiln_web/components/operator_chrome.ex` | exact |
| LiveView disconnected-state hero on operator pages | liveview | request-response | `lib/kiln_web/live/templates_live.ex`, `lib/kiln_web/live/run_board_live.ex`, `lib/kiln_web/live/provider_health_live.ex`, `lib/kiln_web/live/onboarding_live.ex` | exact |
| Cross-shell assign hydration for readiness/provider snapshots | hook | event-driven | `lib/kiln_web/live/operator_chrome_hook.ex` | exact |
| Readiness/disconnected-state LiveView tests | test | request-response | `test/kiln_web/live/templates_live_test.exs`, `test/kiln_web/live/run_board_live_test.exs`, `test/kiln_web/live/provider_health_live_test.exs`, `test/kiln_web/live/onboarding_live_test.exs` | exact |
| Recent verification artifact | docs | transform | `.planning/phases/24-template-run-uat-smoke/24-VERIFICATION.md`, `.planning/phases/22-merge-authority-operator-docs/22-VERIFICATION.md` | exact |
| Recent plan summary artifact | docs | transform | `.planning/phases/22-merge-authority-operator-docs/22-01-SUMMARY.md` | exact |

## Pattern Assignments

### Readiness SSOT

**Primary analog:** [lib/kiln/operator_setup.ex](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:1)

**Why this is the Phase 25 anchor**
- It already centralizes the operator-facing readiness story for onboarding, settings, and disconnected live-mode states.
- It exposes one summary shape consumed across multiple LiveViews instead of letting each page invent its own checklist or blocker logic.

**SSOT contract to copy** ([lib/kiln/operator_setup.ex:1](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:1), [39](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:39), [56](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:56), [96](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:96)):
```elixir
def summary do
  checklist = checklist()

  %{
    ready?: Enum.all?(checklist, &(&1.status == :ready)),
    blockers: Enum.filter(checklist, &(&1.status == :action_needed)),
    checklist: checklist,
    providers: providers()
  }
end
```

**Checklist item shape to preserve** ([lib/kiln/operator_setup.ex:13](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:13)-[22](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:22)):
```elixir
@type checklist_item :: %{
  id: atom(),
  title: String.t(),
  status: :ready | :action_needed,
  why: String.t(),
  where_used: String.t(),
  next_action: String.t(),
  href: String.t(),
  probe: String.t()
}
```

**Concrete implementation pattern** ([lib/kiln/operator_setup.ex:58](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:58)-[93](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:93)):
- Read persisted readiness from `Kiln.OperatorReadiness.current_state/0`.
- Build a stable checklist with `id`, operator-facing explanation, next action, and probe string.
- Derive `ready?` from checklist status, not from duplicated page-local booleans.

**Apply to Phase 25**
- Any new readiness/disconnected-state surface should consume `OperatorSetup.summary/0` or a narrow extension of that module.
- Do not add page-local copies of `:anthropic`, `:github`, `:docker` decision logic.

---

### Shell-Level Readiness Chrome

**Primary analog:** [lib/kiln_web/components/operator_chrome.ex](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:1)

**Stable IDs and shell contract** ([lib/kiln_web/components/operator_chrome.ex:17](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:17)-[33](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:33), [127](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:127)-[174](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:174)):
```elixir
<span id="operator-mode-chip" ...>
...
<details id="operator-config-presence" ...>
...
<div id="operator-provider-readiness" role="status" class="mt-1.5">
```

**Mode-specific readiness logic** ([lib/kiln_web/components/operator_chrome.ex:196](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:196)-[226](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:226)):
```elixir
defp readiness_inner(:live, snapshots) do
  cond do
    Enum.any?(snapshots, &(not &1[:key_configured?])) ->
      readiness_block(
        "Credential not configured",
        "This provider needs a configured secret reference in the runtime environment."
      )

    Enum.any?(snapshots, &rate_degraded?/1) ->
      readiness_block(
        "Provider not reachable",
        "Runs may stall until connectivity returns."
      )

    true ->
      :empty
  end
end
```

**Banner composition pattern** ([lib/kiln_web/components/operator_chrome.ex:228](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:228)-[245](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:245)):
```elixir
<div class="kiln-readiness-banner">
  <.icon name="hero-signal-slash" class="mt-0.5 size-4 shrink-0" />
  <div class="flex-1">
    <div class="kiln-readiness-banner__title">{@title}</div>
    <p class="kiln-readiness-banner__body">{@body}</p>
    <p class="mt-1.5">
      <.link navigate={~p"/providers"} class="link link-primary text-[13px]">
        Open provider health
      </.link>
    </p>
  </div>
</div>
```

**Apply to Phase 25**
- Preserve the existing operator-shell ids instead of inventing new test-only hooks.
- Keep copy short, concrete, and action-oriented: what happened, what still works, where to go next.
- Keep secrets out of the shell; `operator_config_presence/1` reports names and configured counts only.

---

### Layout Integration

**Primary analog:** [lib/kiln_web/components/layouts.ex](/Users/jon/projects/kiln/lib/kiln_web/components/layouts.ex:33)

**Required assign surface** ([lib/kiln_web/components/layouts.ex:33](/Users/jon/projects/kiln/lib/kiln_web/components/layouts.ex:33)-[65](/Users/jon/projects/kiln/lib/kiln_web/components/layouts.ex:65)):
- `:operator_runtime_mode`
- `:operator_snapshots`
- `:operator_demo_scenario`
- `:operator_demo_scenarios`
- `:chrome_mode`

**Operator shell wiring pattern** ([lib/kiln_web/components/layouts.ex:68](/Users/jon/projects/kiln/lib/kiln_web/components/layouts.ex:68)-[172](/Users/jon/projects/kiln/lib/kiln_web/components/layouts.ex:172)):
- Header-level controls stay in `Layouts.app`.
- `chrome_mode: :minimal` suppresses extra telemetry for first-run surfaces.
- Full chrome renders summary chips in the subheader plus the provider-readiness banner below.

**Built-in disconnected transport flash pattern** ([lib/kiln_web/components/layouts.ex:185](/Users/jon/projects/kiln/lib/kiln_web/components/layouts.ex:185)-[215](/Users/jon/projects/kiln/lib/kiln_web/components/layouts.ex:215)):
```elixir
<.flash
  id="client-error"
  kind={:error}
  title="We can't find the internet"
  phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
  phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
  hidden
>
```

**Apply to Phase 25**
- Any new operator-facing readiness UI belongs inside `Layouts.app` conventions, not ad hoc wrappers.
- If Phase 25 touches transport disconnect messaging, reuse `flash_group/1` behavior instead of adding another global reconnect indicator.

---

### Per-Page Disconnected-State Hero

**Best analogs**
- [lib/kiln_web/live/run_board_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/run_board_live.ex:251)
- [lib/kiln_web/live/templates_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:176)
- [lib/kiln_web/live/provider_health_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/provider_health_live.ex:86)
- [lib/kiln_web/live/onboarding_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/onboarding_live.ex:111)

**Canonical guard condition**
```elixir
<%= if @operator_runtime_mode == :live and not @setup_summary.ready? do %>
```

**Run board analog** ([lib/kiln_web/live/run_board_live.ex:251](/Users/jon/projects/kiln/lib/kiln_web/live/run_board_live.ex:251)-[272](/Users/jon/projects/kiln/lib/kiln_web/live/run_board_live.ex:272)):
- `id="run-board-live-hero"`
- explains the page still works for situational awareness
- points to `/settings`
- offers a secondary link that still lets the operator continue exploring

**Templates analog** ([lib/kiln_web/live/templates_live.ex:176](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:176)-[200](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:200), [428](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:428)-[435](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:435)):
```elixir
defp live_disconnected?(:live, %{ready?: false}), do: true

defp use_label(:live, %{ready?: false}, _busy), do: "Configure live mode first"
defp start_label(:live, %{ready?: false}, _busy), do: "Configure live mode first"
```
- This is the strongest analog when the page must both show a hero and disable readiness-sensitive actions.

**Provider health analog** ([lib/kiln_web/live/provider_health_live.ex:86](/Users/jon/projects/kiln/lib/kiln_web/live/provider_health_live.ex:86)-[107](/Users/jon/projects/kiln/lib/kiln_web/live/provider_health_live.ex:107)):
- Good copy pattern for a page that remains useful while live readiness is incomplete.
- “visible, but…” framing is consistent with the shell tone.

**Onboarding analog** ([lib/kiln_web/live/onboarding_live.ex:111](/Users/jon/projects/kiln/lib/kiln_web/live/onboarding_live.ex:111)-[141](/Users/jon/projects/kiln/lib/kiln_web/live/onboarding_live.ex:141)):
- Best analog for first-run framing.
- Uses `chrome_mode={:minimal}` so readiness guidance is not crowded by the shell telemetry.

**Apply to Phase 25**
- Keep the same three-part shape on every disconnected-state hero:
  1. clear state label such as `Disconnected live state` or `Live mode is active`
  2. one sentence about what still works
  3. one primary recovery link plus one secondary exploration link
- Reuse page-level ids of the form `#<surface>-live-hero`.

---

### Readiness Assign Hydration

**Primary analog:** [lib/kiln_web/live/operator_chrome_hook.ex](/Users/jon/projects/kiln/lib/kiln_web/live/operator_chrome_hook.ex:17)

**On-mount assign pattern** ([lib/kiln_web/live/operator_chrome_hook.ex:17](/Users/jon/projects/kiln/lib/kiln_web/live/operator_chrome_hook.ex:17)-[27](/Users/jon/projects/kiln/lib/kiln_web/live/operator_chrome_hook.ex:27)):
```elixir
socket =
  socket
  |> assign(:operator_runtime_mode, mode)
  |> assign(:operator_demo_scenario, scenario)
  |> assign(:operator_demo_scenarios, DemoScenarios.list())
  |> assign(:operator_snapshots, ModelRegistry.provider_health_snapshots())
```

**Tick refresh pattern** ([lib/kiln_web/live/operator_chrome_hook.ex:37](/Users/jon/projects/kiln/lib/kiln_web/live/operator_chrome_hook.ex:37)-[48](/Users/jon/projects/kiln/lib/kiln_web/live/operator_chrome_hook.ex:48)):
- `attach_hook/4` on `:handle_info`
- refresh `:operator_snapshots`
- re-arm the timer every `5_000` ms

**Apply to Phase 25**
- If a new readiness surface needs shell-wide data, hydrate it in the hook or a shared service and pass it through `Layouts.app`.
- Avoid page-specific ad hoc reads of provider snapshots if the shell already owns that state.

---

### LiveView Test Conventions

**Base test seam:** [test/support/conn_case.ex](/Users/jon/projects/kiln/test/support/conn_case.ex:27)

**Default readiness behavior** ([test/support/conn_case.ex:27](/Users/jon/projects/kiln/test/support/conn_case.ex:27)-[40](/Users/jon/projects/kiln/test/support/conn_case.ex:40)):
```elixir
readiness =
  if tags[:operator_readiness] == :keep do
    nil
  else
    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:github, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, true)
    :ready
  end
```

**What this means for Phase 25**
- The default `ConnCase` makes the app ready.
- Tests for disconnected-state surfaces must explicitly flip one readiness step back to `false` after setup.
- Keep these modules `async: false` when they mutate singleton runtime mode/readiness state.

**Best LiveView test analogs**

1. [test/kiln_web/live/templates_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/templates_live_test.exs:1)
   - strongest operator-path pattern
   - uses ids as primary contract
   - covers disabled/disconnected state and routed navigation with `follow_redirect/3`

2. [test/kiln_web/live/run_board_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/run_board_live_test.exs:42)
   - strongest analog for board-like operator surfaces
   - disconnected hero asserted by id first

3. [test/kiln_web/live/provider_health_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/provider_health_live_test.exs:45)
   - strongest analog for a page that remains functional under incomplete readiness
   - also covers refresh behavior via `send(view.pid, :tick)`

4. [test/kiln_web/live/onboarding_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/onboarding_live_test.exs:20)
   - strongest analog for first-run layout and scenario switching

5. [test/kiln_web/live/operator_chrome_hook_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/operator_chrome_hook_test.exs:9)
   - minimal seam for shell-hook mount and tick no-crash proof

**Concrete conventions to copy**
- Mount with `live(conn, ~p"...")`.
- Assert ids first with `has_element?/2`.
- Use text assertions only as secondary proof of the operator-visible state.
- For form/state changes, drive the real form id: `form("#operator-mode-form", ...) |> render_change()`.
- For navigation, follow redirect and prove the destination shell by id rather than deeper HTML snapshots.

---

### Recent Verification Artifact Style

**Best analogs**
- [24-VERIFICATION.md](/Users/jon/projects/kiln/.planning/phases/24-template-run-uat-smoke/24-VERIFICATION.md:1)
- [22-VERIFICATION.md](/Users/jon/projects/kiln/.planning/phases/22-merge-authority-operator-docs/22-VERIFICATION.md:1)
- [999.2-VERIFICATION.md](/Users/jon/projects/kiln/.planning/phases/999.2-operator-demo-vs-live-mode-and-provider-readiness-ux/999.2-VERIFICATION.md:1)

**Phase 24 style to copy for a narrow UI slice** ([24-VERIFICATION.md:1](/Users/jon/projects/kiln/.planning/phases/24-template-run-uat-smoke/24-VERIFICATION.md:1)-[31](/Users/jon/projects/kiln/.planning/phases/24-template-run-uat-smoke/24-VERIFICATION.md:31)):
- frontmatter with `status`, `phase`, `verified`, `requirements`
- short `## Automated` table
- exact repo-root commands block
- one sentence on scope boundary
- `## Human verification` and `## Gaps` both explicit, even when empty

**Phase 22 style to copy for docs-heavy or grep-backed verification** ([22-VERIFICATION.md:11](/Users/jon/projects/kiln/.planning/phases/22-merge-authority-operator-docs/22-VERIFICATION.md:11)-[43](/Users/jon/projects/kiln/.planning/phases/22-merge-authority-operator-docs/22-VERIFICATION.md:43)):
- `| Check | Result |` table
- separate `Commands (repo root)` block
- `## Must-haves` table if plan commitments need one-by-one closure

**Phase 999.2 style to copy for readiness-shell work** ([999.2-VERIFICATION.md:19](/Users/jon/projects/kiln/.planning/phases/999.2-operator-demo-vs-live-mode-and-provider-readiness-ux/999.2-VERIFICATION.md:19)-[31](/Users/jon/projects/kiln/.planning/phases/999.2-operator-demo-vs-live-mode-and-provider-readiness-ux/999.2-VERIFICATION.md:19)):
- short “Must-haves (from plans)” bullets tying exact files/tests to outcomes
- good fit if Phase 25 is mostly SSOT alignment rather than net-new behavior

---

### Recent Summary Artifact Style

**Primary analog:** [22-01-SUMMARY.md](/Users/jon/projects/kiln/.planning/phases/22-merge-authority-operator-docs/22-01-SUMMARY.md:1)

**Shape to preserve**
- YAML frontmatter with `phase`, `plan`, `subsystem`, `tags`, `key-files`, `key-decisions`, `requirements-completed`, `completed`
- brief prose statement of what shipped
- compact sections: `## Performance`, `## Task commits`, `## Deviations`, `## Self-Check`

**Why this matters for Phase 25**
- It is concise, grep-friendly, and evidence-oriented.
- It avoids narrative drift by tying summary claims back to requirements and exact files.

## Shared Patterns

### One Readiness Story, Many Surfaces
**Source:** [lib/kiln/operator_setup.ex](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:1), [lib/kiln_web/live/settings_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/settings_live.ex:74), [lib/kiln_web/live/onboarding_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/onboarding_live.ex:222)

- Use one shared summary/checklist/provider model.
- Let each page adapt presentation and CTA, not the underlying readiness rules.

### Live Mode Can Be Incomplete Without Hiding the Product
**Source:** [lib/kiln_web/live/run_board_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/run_board_live.ex:251), [lib/kiln_web/live/templates_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:176), [lib/kiln_web/live/provider_health_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/provider_health_live.ex:86)

- The house pattern is “keep the page explorable, but show honest disconnected-state affordances.”
- Do not redirect away from every live-sensitive page by default.

### Id-First Operator UI Tests
**Source:** [test/kiln_web/live/templates_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/templates_live_test.exs:26), [test/kiln_web/live/run_board_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/run_board_live_test.exs:31)

- Stable ids are the primary test seam.
- Text assertions stay secondary and scoped to operator-visible copy changes.

### Verification Artifacts Stay Narrow and Mechanical
**Source:** [24-VERIFICATION.md](/Users/jon/projects/kiln/.planning/phases/24-template-run-uat-smoke/24-VERIFICATION.md:9), [22-VERIFICATION.md](/Users/jon/projects/kiln/.planning/phases/22-merge-authority-operator-docs/22-VERIFICATION.md:9)

- Cite exact commands actually run.
- State what the evidence proves and what it does not replace.

## Anti-Patterns Or Drift To Avoid

| Drift / anti-pattern | Evidence | Why Phase 25 should avoid it |
|---|---|---|
| Stale assumption that `OnboardingGate` still hard-redirects readiness-sensitive routes | [lib/kiln_web/plugs/onboarding_gate.ex](/Users/jon/projects/kiln/lib/kiln_web/plugs/onboarding_gate.ex:1) is now pass-through, but [24-PATTERNS.md](/Users/jon/projects/kiln/.planning/phases/24-template-run-uat-smoke/24-PATTERNS.md:12) still describes redirect behavior | Phase 25 is explicitly SSOT work. Do not carry old gate semantics into plans, docs, or tests. |
| Copy-pasted per-page readiness verification handlers | [lib/kiln_web/live/onboarding_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/onboarding_live.ex:33) and [lib/kiln_web/live/settings_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/settings_live.ex:21) repeat the same `verify_*` and `after_verify` pattern | If Phase 25 touches readiness actions, prefer extracting shared behavior instead of adding a third or fourth copy. |
| Page-local disconnected-state logic drifting from shared readiness semantics | [lib/kiln_web/live/templates_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:428) has local gating helpers, while page heroes elsewhere key directly off `@setup_summary.ready?` | If Phase 25 unifies local live readiness, centralize labels/guards where possible and avoid further divergence. |
| Overreliance on raw `render(view) =~ ...` assertions for structural states | Present in several tests, for example [operator_chrome_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/operator_chrome_live_test.exs:27) and [run_board_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/run_board_live_test.exs:37) | Keep Phase 25 tests id-first. Use text only to verify important operator copy, not as the primary structure contract. |
| Hiding disconnected-state behavior behind always-ready test setup | [test/support/conn_case.ex](/Users/jon/projects/kiln/test/support/conn_case.ex:30) marks readiness true by default | Phase 25 tests need explicit incomplete-readiness setup or they will miss the exact operator state this phase is meant to govern. |

## No Better Analog Found

| Candidate need | Best available analog | Gap |
|---|---|---|
| A single shared disconnected-state component used by every live-sensitive page | Page-local heroes in `run_board`, `templates`, `providers`, `onboarding` | The repo has consistent copy and CTA shape, but not yet one extracted HEEx component. |
| A single shared readiness-event handler for onboarding/settings | Duplicate handlers in `OnboardingLive` and `SettingsLive` | The repo has a repeated pattern, not a shared abstraction yet. |

## Best Analogs To Follow

- SSOT logic: [lib/kiln/operator_setup.ex](/Users/jon/projects/kiln/lib/kiln/operator_setup.ex:39)
- Shell readiness chrome: [lib/kiln_web/components/operator_chrome.ex](/Users/jon/projects/kiln/lib/kiln_web/components/operator_chrome.ex:165)
- Page-level disconnected state: [lib/kiln_web/live/templates_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:176) for action gating, [lib/kiln_web/live/run_board_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/run_board_live.ex:251) for board framing
- Readiness test seam: [test/support/conn_case.ex](/Users/jon/projects/kiln/test/support/conn_case.ex:27) plus [test/kiln_web/live/templates_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/templates_live_test.exs:86)
- Verification artifact style: [24-VERIFICATION.md](/Users/jon/projects/kiln/.planning/phases/24-template-run-uat-smoke/24-VERIFICATION.md:9) with [22-VERIFICATION.md](/Users/jon/projects/kiln/.planning/phases/22-merge-authority-operator-docs/22-VERIFICATION.md:27) for must-have tables
