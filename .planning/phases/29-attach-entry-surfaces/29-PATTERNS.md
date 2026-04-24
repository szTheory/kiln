# Phase 29: Attach Entry Surfaces - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 7
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kiln_web/router.ex` | route | request-response | `lib/kiln_web/router.ex` | exact |
| `lib/kiln_web/live/attach_entry_live.ex` | component | request-response | `lib/kiln_web/live/onboarding_live.ex` + `lib/kiln_web/live/templates_live.ex` | role-match |
| `lib/kiln_web/live/onboarding_live.ex` | component | request-response | `lib/kiln_web/live/onboarding_live.ex` | exact |
| `lib/kiln_web/live/templates_live.ex` | component | request-response | `lib/kiln_web/live/templates_live.ex` | exact |
| `lib/kiln_web/live/run_board_live.ex` | component | request-response | `lib/kiln_web/live/run_board_live.ex` | exact |
| `test/kiln_web/live/attach_entry_live_test.exs` | test | request-response | `test/kiln_web/live/onboarding_live_test.exs` + `test/kiln_web/live/templates_live_test.exs` | role-match |
| `test/kiln_web/live/route_smoke_test.exs` | test | request-response | `test/kiln_web/live/route_smoke_test.exs` | exact |

## Pattern Assignments

### `lib/kiln_web/router.ex` (route, request-response)

**Analog:** `lib/kiln_web/router.ex:21-47`

Copy the new attach route into the existing `scope "/"` and `live_session :default`. Do not create a new session, pipeline, or scope just for attach.

**Route/session pattern** (`lib/kiln_web/router.ex:21-47`):
```elixir
scope "/", KilnWeb do
  pipe_through :browser

  live_session :default,
    on_mount: [
      {KilnWeb.LiveScope, :default},
      {KilnWeb.FactorySummaryHook, :default},
      {KilnWeb.OperatorChromeHook, :default}
    ] do
    live "/onboarding", OnboardingLive, :index
    live "/", RunBoardLive, :index
    live "/templates", TemplatesLive, :index
    live "/templates/:template_id", TemplatesLive, :show
    ...
    live "/settings", SettingsLive, :index
  end
end
```

**Planner note:** add `live "/attach", AttachEntryLive, :index` in this block so attach inherits the same shell assigns and route-smoke coverage expectations.

---

### `lib/kiln_web/live/attach_entry_live.ex` (component, request-response)

**Primary analogs:**
- Entry-flow shell: `lib/kiln_web/live/onboarding_live.ex:66-220`
- Start-surface module/card composition: `lib/kiln_web/live/templates_live.ex:179-349`
- Calm remediation/orientation copy: `lib/kiln_web/live/settings_live.ex:80-156`

Use one route-backed LiveView with plain `mount/3` assigns and no hidden modal state. This page is orientation-only in Phase 29.

**LiveView shell pattern** (`lib/kiln_web/live/onboarding_live.ex:68-77`, `lib/kiln_web/live/templates_live.ex:170-178`):
```elixir
<Layouts.app
  flash={@flash}
  current_scope={@current_scope}
  factory_summary={@factory_summary}
  operator_runtime_mode={@operator_runtime_mode}
  operator_snapshots={@operator_snapshots}
  operator_demo_scenario={@operator_demo_scenario}
  operator_demo_scenarios={@operator_demo_scenarios}
>
```

**If attach should feel first-run focused, use minimal chrome** from onboarding (`lib/kiln_web/live/onboarding_live.ex:68-77`):
```elixir
<Layouts.app
  ...
  chrome_mode={:minimal}
>
```

**Page wrapper + section rhythm** (`lib/kiln_web/live/templates_live.ex:179-186`, `lib/kiln_web/live/settings_live.ex:71-80`):
```elixir
<div id="templates-root" class="mx-auto max-w-5xl space-y-8 text-base-content">
  <header class="border-b border-base-300 pb-4">
    <p class="kiln-eyebrow">First live run</p>
    <h1 class="kiln-h1 mt-1">{@page_title}</h1>
  </header>
</div>
```

**Card/module composition pattern** from onboarding/templates/settings:
- outer card: `rounded-xl border border-base-300 bg-base-200 p-5`
- emphasized hero: `rounded-2xl border ...`
- secondary inset blocks: `rounded-lg border border-base-300 bg-base-200/60 p-3`

Use these concrete analogs:
- `lib/kiln_web/live/onboarding_live.ex:87-109`
- `lib/kiln_web/live/templates_live.ex:232-313`
- `lib/kiln_web/live/settings_live.ex:80-156`

**CTA cluster pattern** (`lib/kiln_web/live/onboarding_live.ex:204-218`, `lib/kiln_web/live/run_board_live.ex:178-185`, `lib/kiln_web/live/templates_live.ex:200-209`):
```elixir
<div class="mt-4 flex flex-wrap gap-3 text-sm">
  <.link navigate={...} class="btn btn-primary btn-sm">...</.link>
  <.link navigate={...} class="link link-primary">...</.link>
</div>
```

**Attach page structure to copy:**
- hero block shaped like `templates-first-run-hero` (`lib/kiln_web/live/templates_live.ex:232-313`) but smaller and non-template-specific
- support panels shaped like `settings-summary` cards (`lib/kiln_web/live/settings_live.ex:80-156`)
- one explicit back-link cluster like onboarding/templates (`lib/kiln_web/live/onboarding_live.ex:204-218`, `lib/kiln_web/live/templates_live.ex:481-483`)

**Do not copy these behaviors:**
- scenario `push_patch` flow from onboarding (`lib/kiln_web/live/onboarding_live.ex:23-30`)
- template `return_to` / `template_id` resume plumbing (`lib/kiln_web/live/templates_live.ex:524-528`, `lib/kiln_web/live/settings_live.ex:229-240`)
- template apply/start event handlers (`lib/kiln_web/live/templates_live.ex:76-154`)

---

### `lib/kiln_web/live/onboarding_live.ex` (component, request-response)

**Analog:** `lib/kiln_web/live/onboarding_live.ex:78-220`

This is the closest analog for adding a secondary attach CTA beside an existing primary next-step flow.

**Scenario-driven next-step panel pattern** (`lib/kiln_web/live/onboarding_live.ex:180-218`):
```elixir
<article class="rounded-xl border border-base-300 bg-base-200 p-5">
  <p class="kiln-eyebrow">Recommended next step</p>
  <h2 class="kiln-h2 mt-2">Open the matching template</h2>
  ...
  <div class="mt-4 flex flex-col gap-3">
    <.link
      id="onboarding-start-from-template"
      navigate={~p"/templates?from=onboarding&scenario=#{@operator_demo_scenario.id}"}
      class="btn btn-primary"
    >
      Open recommended template
    </.link>
    <.link id="onboarding-continue-runs" navigate={~p"/"} class="link link-primary">
      Open run board
    </.link>
  </div>
</article>
```

**Selection-card pattern** (`lib/kiln_web/live/onboarding_live.ex:154-177`):
```elixir
<button
  id={"scenario-card-#{scenario.id}"}
  ...
  class={[
    "rounded-xl border p-5 text-left transition",
    selected && "border-primary bg-base-200 shadow-[0_0_0_1px_var(--color-primary)]",
    !selected && "border-base-300 bg-base-200 hover:border-primary/50"
  ]}
>
```

**Use here:** add attach as a separate CTA in the existing next-step cluster. Keep template CTA primary and attach CTA secondary bordered/button treatment, not plain text.

---

### `lib/kiln_web/live/templates_live.ex` (component, request-response)

**Analog:** `lib/kiln_web/live/templates_live.ex:179-349`

This is the best analog for the primary attach discovery surface. It already encodes the Start IA, hero emphasis, side module composition, and stable card ids.

**Start hero pattern** (`lib/kiln_web/live/templates_live.ex:231-313`):
```elixir
<section
  :if={@first_run_template}
  id="templates-first-run-hero"
  class="overflow-hidden rounded-2xl border border-primary/40 bg-base-200"
>
  <div class="grid gap-6 p-6 lg:grid-cols-[1.3fr_0.9fr]">
    <article id={"template-card-#{t.id}"} class="rounded-xl border ... p-5">
      ...
    </article>

    <aside class="space-y-3 rounded-xl border border-base-300 bg-base-100/40 p-5">
      ...
    </aside>
  </div>
</section>
```

**Catalog card/id pattern** (`lib/kiln_web/live/templates_live.ex:315-347`):
```elixir
<article
  id={"template-card-#{t.id}"}
  class="flex flex-col rounded border border-base-300 bg-base-200 p-4 shadow-none"
>
  <span id={"template-role-#{t.id}"} class="kiln-eyebrow mb-3 w-fit">
    {template_role_label(t.id)}
  </span>
  ...
</article>
```

**Disconnected-state pattern** (`lib/kiln_web/live/templates_live.ex:188-211`, `428-447`):
```elixir
<section id="templates-live-hero" class="rounded-xl border border-warning/60 bg-warning/10 p-5">
  ...
  <div class="mt-4 flex flex-wrap gap-3 text-sm">
    <.link navigate={~p"/settings"} class="btn btn-primary btn-sm">
      Open settings checklist
    </.link>
    <.link ... class="link link-primary">Return to onboarding</.link>
  </div>
</section>
```

**Use here:** add an attach peer module near `#templates-first-run-hero`, above the broader catalog. Keep `hello-kiln` as the largest hero and make attach a first-class secondary module.

**Naming pattern to copy for new ids:**
- page root: `templates-root`
- hero/module root: `templates-first-run-hero`
- action button: `templates-start-run`
- card by slug: `template-card-#{slug}`
- role badge by slug: `template-role-#{slug}`

For attach, follow the same surface-prefixed pattern, e.g. `attach-entry-root`, `templates-attach-module`, `templates-attach-existing-repo`.

---

### `lib/kiln_web/live/run_board_live.ex` (component, request-response)

**Analog:** `lib/kiln_web/live/run_board_live.ex:163-290`

Use this only for a minor convenience shortcut. The board stays a monitoring surface.

**Overview-card CTA pattern** (`lib/kiln_web/live/run_board_live.ex:170-185`):
```elixir
<section class="rounded-xl border border-base-300 bg-base-200 p-4">
  <p id="run-board-journey-title" class="kiln-eyebrow">
    {journey_title(@operator_demo_scenario)}
  </p>
  ...
  <div class="mt-3 flex flex-wrap gap-3 text-sm">
    <.link navigate={onboarding_path(@operator_demo_scenario)} class="link link-primary">
      Open setup
    </.link>
    <.link navigate={templates_path(@operator_demo_scenario)} class="link link-primary">
      Browse templates
    </.link>
  </div>
</section>
```

**Empty-state pattern** (`lib/kiln_web/live/run_board_live.ex:274-289`):
```elixir
<section class="card card-bordered bg-base-200 border-base-300">
  <div class="card-body p-8">
    <h2 class="kiln-h2">No runs in flight</h2>
    ...
    <div class="mt-4 flex flex-wrap gap-3 text-sm">
      <.link ... class="link link-primary">Verify setup</.link>
      <.link ... class="link link-primary">Start from a template</.link>
    </div>
  </div>
</section>
```

**Use here:** if Phase 29 adds an attach shortcut on `/`, place it in this CTA cluster as a third minor link with its own id, e.g. `run-board-attach-shortcut`. Do not promote it above `Browse templates`.

---

### `test/kiln_web/live/attach_entry_live_test.exs` (test, request-response)

**Primary analogs:**
- shell/id presence tests: `test/kiln_web/live/onboarding_live_test.exs:20-30`
- route + CTA + redirect tests: `test/kiln_web/live/templates_live_test.exs:32-172`
- chrome/shell assertions: `test/kiln_web/live/operator_chrome_live_test.exs:21-93`

**Selector-first LiveView test pattern** (`test/kiln_web/live/onboarding_live_test.exs:20-30`):
```elixir
{:ok, view, _html} = live(conn, ~p"/onboarding")
assert has_element?(view, "#onboarding-wizard")
assert has_element?(view, "#onboarding-next-path")
```

**Navigation/result pattern** (`test/kiln_web/live/templates_live_test.exs:97-110`, `128-141`):
```elixir
result =
  view
  |> form("#templates-start-run-form")
  |> render_submit()

assert {:error, {:live_redirect, %{to: to}}} = result
{:ok, redirected_view, _html} = follow_redirect(result, conn)
```

**Recommended tests for attach page:**
- mount `/attach` and assert `#attach-entry-root`, `#attach-entry-hero`, `#attach-supported-sources`, `#attach-next-step`, `#attach-back-to-templates`
- from `/templates`, assert `#templates-attach-module` and a link/button `#templates-attach-existing-repo[href="/attach"]`
- from `/onboarding`, assert `#onboarding-attach-existing-repo[href="/attach"]`
- if `/` shortcut ships, assert `#run-board-attach-shortcut[href="/attach"]`

---

### `test/kiln_web/live/route_smoke_test.exs` (test, request-response)

**Analog:** `test/kiln_web/live/route_smoke_test.exs:91-175`

This is the route-backed smoke guard for all default LiveViews. New attach route should be added here.

**Index-route smoke pattern** (`test/kiln_web/live/route_smoke_test.exs:91-105`):
```elixir
for path <- [
      "/onboarding",
      "/",
      "/templates",
      ...
      "/settings",
      "/audit"
    ] do
  assert_route_renders_cleanly(conn, path)
end
```

**Shared assertion contract** (`test/kiln_web/live/route_smoke_test.exs:146-175`):
```elixir
assert has_element?(view, "header"),
       "#{path}: missing <header> landmark (operator chrome)"

for token <- @legacy_tokens do
  refute String.contains?(html, token)
end
```

**Planner note:** add `"/attach"` to the index route list and, if attach gets unique anchors, add one focused smoke assertion like the existing `templates-first-run-hero` check.

## Shared Patterns

### Shared Shell / Navigation

**Sources:**
- `lib/kiln_web/components/layouts.ex:68-169`
- `lib/kiln_web/components/operator_chrome.ex:38-174`

**Apply to:** all attach-facing LiveViews

- Wrap every page in `<Layouts.app ...>` with the standard assigns.
- Use `.link navigate={...}` for route changes; do not use modals or inline script navigation.
- Keep attach inside the existing operator shell so route smoke keeps seeing a `<header>`.
- `Start` in the global nav already points to `templates_path(@operator_demo_scenario)` (`lib/kiln_web/components/layouts.ex:92-99`). Phase 29 attach should augment Start IA, not replace the nav contract.

**Concrete excerpt** (`lib/kiln_web/components/layouts.ex:87-105`):
```elixir
<nav aria-label="Operator">
  <ul class="flex flex-wrap items-center gap-x-1 gap-y-1 sm:gap-x-2">
    <li>
      <.link class="kiln-nav-link font-sans" navigate={~p"/"}>Runs</.link>
    </li>
    <li>
      <.link
        class="kiln-nav-link font-sans"
        navigate={templates_path(@operator_demo_scenario)}
      >
        Start
      </.link>
    </li>
```

### Minimal vs Full Chrome

**Sources:**
- `lib/kiln_web/components/layouts.ex:60-64`
- `lib/kiln_web/components/layouts.ex:142-161`
- `lib/kiln_web/live/onboarding_live.ex:68-77`

**Apply to:** `/attach`, `/onboarding`, any first-run surface that should not be crowded by operator telemetry

Use `chrome_mode={:minimal}` if attach should behave like onboarding. Use default chrome if attach should feel like the rest of the app.

### Scenario Context Handling

**Sources:**
- `lib/kiln_web/live/onboarding_live.ex:19-30`
- `lib/kiln_web/live/templates_live.ex:32-57`
- `lib/kiln_web/components/layouts.ex:93-105`

**Apply to:** modified onboarding/templates/run board surfaces

- Scenario flows are route/query based.
- Scenario-aware links use helper functions like `templates_path(@operator_demo_scenario)` or explicit `?scenario=...`.
- Attach should not overload `scenario`, `template_id`, or `return_to`.

### Return/Resume Plumbing Boundary

**Sources:**
- `lib/kiln_web/live/templates_live.ex:524-528`
- `lib/kiln_web/live/settings_live.ex:137-156`
- `lib/kiln_web/live/settings_live.ex:229-240`

**Apply to:** planner guardrails

Template resume currently assumes a template route:

```elixir
defp return_to_path(:show, %{"template_id" => id}, scenario) when is_binary(id) and id != "" do
  template_path(id, scenario)
end
```

```elixir
defp return_context(%{"return_to" => return_to, "template_id" => template_id})
     when is_binary(return_to) and is_binary(template_id) do
  uri = URI.parse(return_to)

  if String.starts_with?(uri.path || "", "/templates/") do
    %{path: return_to, template_id: template_id}
  else
    nil
  end
end
```

Do not extend this for attach in Phase 29.

### Naming / ID Convention

**Sources:**
- `lib/kiln_web/live/onboarding_live.ex:78-220`
- `lib/kiln_web/live/templates_live.ex:179-483`
- `lib/kiln_web/live/run_board_live.ex:163-290`
- `lib/kiln_web/live/settings_live.ex:71-218`

**Apply to:** all new attach ids

Current convention is:
- page root: `<surface>-root` or a single canonical page id (`onboarding-wizard`, `run-board`, `settings-root`, `templates-root`)
- sections/modules: `<surface>-<section>`
- action/link/button ids: `<surface>-<action>`
- repeatable cards: `<thing>-card-#{slug}` or `<surface>-item-#{id}`

Recommended attach ids:
- `attach-entry-root`
- `attach-entry-hero`
- `attach-supported-sources`
- `attach-next-step`
- `attach-back-to-templates`
- `templates-attach-module`
- `templates-attach-existing-repo`
- `onboarding-attach-existing-repo`
- `run-board-attach-shortcut`

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| none | - | - | Phase 29 attach surfaces fit existing route-backed LiveView and card/module patterns well. |

## Metadata

**Analog search scope:** `lib/kiln_web/router.ex`, `lib/kiln_web/components/*.ex`, `lib/kiln_web/live/*`, `test/kiln_web/live/*`, phase docs  
**Files scanned:** 14  
**Pattern extraction date:** 2026-04-24
