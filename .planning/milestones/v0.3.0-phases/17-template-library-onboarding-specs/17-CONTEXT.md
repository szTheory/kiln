# Phase 17: Template library & onboarding specs - Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **WFE-01** + **ONB-01**: a **git-versioned built-in template library** (workflow YAML + spec markdown **pairs**) under **`priv/`**, with **operator-visible metadata** (purpose, **advisory** time/cost bands, last-verified provenance), and **clear instantiate + run flows** that respect **Phase 8** (runs bind only to **promoted** specs). **One intentional operator journey** lowers time-to-first-successful-run without implying guarantees on spend or duration (bounded autonomy + caps stay authoritative).

Out of scope: **WFE-02** workflow signing, remote/marketplace catalogs, Postgres as canonical store for shipped template bodies, multi-tenant sharing.

</domain>

<decisions>
## Implementation Decisions

### Research basis (2026-04-22)

Four parallel research passes covered **(1)** on-disk layout + indexing, **(2)** instantiate vs promote vs run semantics, **(3)** information architecture, **(4)** metadata and estimate copy. Below locks a **single coherent** approach aligned with **Specs vs Intents** boundaries, **`Application.app_dir/2`** release safety, and prior art (GitHub template / Actions separation of “materialize” vs “execute”, Notion/Linear catalog vs workspace, false-precision lessons from cloud calculators and CI minutes).

### Template packs & indexing (D-1701..D-1705)

- **D-1701 — Directory + manifest:** Ship each built-in at **`priv/templates/<template_id>/`** with the **paired** assets (convention: `spec.md` + workflow file named in manifest, e.g. `workflow.yaml`). Maintain **`priv/templates/manifest.json`** (or `.yaml` if team prefers one parser — **pick one** in plan) as the **authoritative index** of built-in IDs and paths. **No** convention-only discovery across unrelated folders (avoids orphan workflow/spec drift).
- **D-1702 — Runtime resolution:** Load **only** through paths joined from **`Application.app_dir(:kiln, …)`** — never cwd-relative `priv/...` for shipped templates (same release/dev footgun class called out for workflows elsewhere).
- **D-1703 — Loader safety:** Template pickers resolve **`template_id` against the manifest allow-list** only — no path join from untrusted freeform strings (path traversal class).
- **D-1704 — CI / tests:** One **exhaustive** test or **`mix`** task (e.g. `mix templates.verify`) iterates every manifest entry: **workflow parses + JSV validates** via existing **`Kiln.Workflows`** pipeline; **spec file** readable UTF-8; **IDs unique**; optional: workflow `id` / stem consistency rules documented in plan.
- **D-1705 — Codegen optional, not v1:** Do **not** require Mix codegen or `@external_resource` for MVP. Optional later: generated Elixir module for **fast tab completion** or compile-time manifest hash — if added, codegen holds **metadata + paths**, not embedded large markdown bodies.

### Instantiate semantics & audit (D-1706..D-1712)

- **D-1706 — Phase 8 invariant:** Runs **never** attach to unpromoted drafts. Any template path that ends in a run **must** pass through a **promoted** `Spec` + `SpecRevision` (existing `promote_draft/1` transaction or equivalent **audited** promotion semantics).
- **D-1707 — Default primary path (vetted templates):** Primary CTA **“Use template”** produces a **promoted spec** in **one operator gesture** (implementation detail for planner: **either** create a short-lived `spec_drafts` row and call **`Kiln.Specs.promote_draft/1` immediately** in the same user action — maximizing reuse of audit `:spec_draft_promoted` — **or** insert `Spec` + `SpecRevision` with a **new** audit kind such as `spec_instantiated_from_template` if drafts are skipped; **choose one** and document — both are acceptable if audit + transaction boundaries are clear).
- **D-1708 — Secondary path — “Edit first”:** Offer **“Edit in inbox first”** (or equivalent) → creates a normal **open** draft only; operator uses existing **inbox edit → promote** flow before run.
- **D-1709 — Run is explicit execution intent:** **“Start run”** (microcopy per brand book) is the **execution** step, implemented under **`Kiln.Intents`** (enqueue) when wired, with **readiness + caps** enforced **before** a run enters `queued`. **Do not** silently start runs on template pick unless a **single combined** control exists and gates pass (see D-1710).
- **D-1710 — WFE-01 “one action” interpretation:** Satisfy operator expectations with **one screen / one flow**: after successful instantiate, show **promoted spec summary** with **adjacent “Start run”** (default happy path = **two deliberate clicks** — template → run — without leaving the flow). **Optional** tertiary **“Use template & start run”** only when **onboarding/readiness is green** and copy states assumptions; same **idempotency** rules as a single enqueue.
- **D-1711 — Idempotency:** Template instantiate and run-start each use **deterministic idempotency keys** (`external_operations` and/or Oban unique patterns already in project). Double-submit / retry must **not** create duplicate specs or runs.
- **D-1712 — Bounded autonomy:** Template choice does **not** bypass caps, provider readiness, or Docker policy — failures return **calm, actionable** errors at the **enqueue** boundary.

### Operator IA & routes (D-1713..D-1718)

- **D-1713 — Canonical catalog route:** Add **`/templates`** as the **primary** browse + preview + instantiate surface (new LiveView). Stable URLs: index + optional **`/templates/:template_id`** preview. Filters via query params (e.g. `?tag=dogfood`) for bookmarkability and docs deep links.
- **D-1714 — Inbox stays triage:** Do **not** host the full template catalog as a permanent **`/inbox`** tab (avoids “mail vs store” confusion). **`/inbox`** remains drafts / promote / archive / imports per Phase 8.
- **D-1715 — Onboarding bridge:** **`/onboarding`** includes a **short** optional step or CTA: “Start from a template” → links to **`/templates?from=onboarding`** or one-click **featured** template that still resolves through the **same** template ID + manifest (no special-case magic path).
- **D-1716 — Generalize dogfood control:** Replace inbox-only **“Load dogfood template”** with either **“Browse templates”** → `/templates` (optionally `?featured=dogfood`) **or** a **featured card** row whose CTA is still **`template_id`**-driven (no separate code path). Prefer **removing dogfood-specific labeling** in UI in favor of **template IDs** (“Game Boy vertical slice”, “Hello Kiln”, …).
- **D-1717 — Post-instantiate navigation:** After **“Edit first”**, land on **`/inbox`** with edit context; after **promote-only** path, land on **`/specs/:id/edit`** (match existing promote redirect pattern) **or** stay on `/templates` with success + **Start run** — pick one consistent success story in plan; default bias: **`/specs/:id/edit`** when further spec edits expected, **`/templates`** success panel when run-first onboarding.
- **D-1718 — `/ops/*` unchanged:** Templates are **domain** routes only (Phase 7/8 contract).

### Metadata & advisory estimates (D-1719..D-1723)

- **D-1719 — Static git metadata:** Each template carries **purpose**, **time_hint**, **cost_hint**, **assumptions** (short bullet list), **last_verified_at**, **last_verified_kiln_version** (or app semver string) in the **manifest entry** and/or **`metadata.yaml`** beside the pair — **adjacent to files**, not only in a duplicated global marketing doc.
- **D-1720 — Bands, not false precision:** Present **ranges** or **qualitative tiers** (“low / moderate”) plus mandatory **non-guarantee** disclaimer tying to **run caps** and actual telemetry variance. Avoid single-dollar cents as **predictions**; if showing computed numbers from **`Kiln.Pricing`**, label as **sanity-checked illustrative** only, never sole source of truth.
- **D-1721 — Optional CI pricing guardrail:** Allow optional fields **`reference_model`**, **`reference_token_budget`** for **CI-only** (or devtool) checks that **indicative** `estimate_usd` stays inside the declared **cost_hint** band after **`priv/pricing/`** updates — **warn or fail** per strictness decided in plan. **Do not** pipe “0 USD” from unknown models into user-visible copy without explanation (pricing helper returns 0 + warning today).
- **D-1722 — i18n:** **English-only** v1 for shipped strings; keep **field keys** stable for future translation.
- **D-1723 — Microcopy patterns:** Use operator-voice examples: **“Typical duration (not a guarantee): …”**, **“Indicative cost (USD): … Actual usage varies with model, retries, and spec changes.”**

### Minimum template set (D-1724)

- **D-1724 — ONB-01 content:** Ship **≥3** vetted templates including one **“Hello Kiln”**-class **fast happy path** (small scope, deterministic scenario, aligns with demo/live mode story). At least one template should exercise **existing dogfood** depth (e.g. vertical slice) **without** relying on special-case loaders — same manifest pipeline.

### Claude's Discretion

- Manifest **JSON vs YAML** choice; exact filename convention inside `priv/templates/<id>/`.
- Whether ephemeral draft + `promote_draft` vs direct spec insert + new audit kind wins on implementation cost.
- Exact LiveView module names, preview layout density, and post-success redirect (D-1717).
- Whether `mix templates.verify` is a **standalone** task or **only** ExUnit — either passes D-1704 if CI always runs it.
- Optional derived `index.json` generated in CI vs hand-written manifest only.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **WFE-01**, **ONB-01** (§ B — Templates & workflow ecosystem)
- `.planning/ROADMAP.md` — Phase 17 goal, success criteria, checklist line (`priv` template packs + UI)
- `.planning/PROJECT.md` — Solo operator, bounded autonomy, brand contract, out-of-scope (no marketplace)

### Prior phase contracts (do not contradict)

- `.planning/phases/08-operator-ux-intake-ops-unblock-onboarding/08-CONTEXT.md` — **D-813..D-820** drafts vs promoted specs; **`Kiln.Specs`** ownership; `/inbox`, `/onboarding`, `/ops` separation
- `.planning/phases/07-core-run-ui-liveview/07-CONTEXT.md` — Domain vs `/ops`, layout/session patterns
- `.planning/phases/02-workflow-engine-core/02-CONTEXT.md` — Workflow load, JSV, signing deferred (**WFE-02**)

### Implementation touchpoints (code)

- `lib/kiln/specs.ex` — `create_draft/1`, `promote_draft/1`, draft lifecycle
- `lib/kiln_web/live/inbox_live.ex` — intake UX; **replace** dogfood-specific affordance per D-1716
- `lib/kiln/dogfood/template.ex` — precedent for **`Application.app_dir(:kiln, "priv/...")`** reads (patterns to generalize, not to duplicate ad hoc)
- `lib/kiln_web/router.ex` — add `/templates` in same `live_session` family as `/inbox`
- `priv/workflows/` — existing shipped workflow examples + JSV schemas under `priv/workflow_schemas/`
- `priv/pricing/v1/` — optional CI cross-check per D-1721
- `prompts/kiln-brand-book.md` — copy tone, palette, state hierarchy for `/templates` UI

### Dogfood / scenario references

- `priv/dogfood/spec.md`, `priv/dogfood/gb_vertical_slice_spec.md`, `priv/workflows/rust_gb_dogfood_v1.yaml` — concrete content patterns for vetted templates (paths may migrate under `priv/templates/` in implementation)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`Kiln.Specs`** — `create_draft/1`, `promote_draft/1`, `update_open_draft/2` — full promote transaction + audit pattern for template → spec materialization.
- **`KilnWeb.InboxLive`** — streams, upload, promote redirect to `~p"/specs/#{spec.id}/edit"` — reference for post-template navigation and flash patterns.
- **`Kiln.Dogfood.Template`** — **`Application.app_dir/2`** read of shipped `priv` file — canonical pattern for release-safe static content.
- **`priv/workflows/*.yaml`** + **`Kiln.Workflows`** — validation pipeline to reuse in **`mix`/ExUnit** verification (D-1704).

### Established Patterns

- **Append-only audit** in same transaction as state changes — template flows must **append** identifiable event kinds (reuse or extend schema in plan).
- **`external_operations`** + idempotency keys — for instantiate and run-start side effects per D-1711.
- **Router** — domain LiveViews outside `/ops`; follow Phase 8 path naming discipline.

### Integration Points

- **New `live "/templates", …`** beside inbox/onboarding routes.
- **Onboarding LiveView** — add CTA or step linking to `/templates` per D-1715.
- **`Kiln.Intents`** — enqueue run after spec materialization when execution wiring is touched (respect placeholder vs real implementation in codebase at plan time).

</code_context>

<specifics>
## Specific Ideas

- User requested **deep cross-domain research** (Cookiecutter / Rails / Yeoman / GitHub templates / Linear / Notion / VS Code starters / AWS Quick Starts) and **one-shot cohesive recommendations** — captured as locked decisions above; **researcher** should not re-litigate unless implementation finds a hard conflict.
- Prior art takeaway emphasized here: **separate “materialize definition” from “execute”** in the mental model, while allowing **tight UX coupling** (adjacent buttons, one flow) for onboarding velocity.

</specifics>

<deferred>
## Deferred Ideas

- **Remote template marketplace**, **WFE-02** signing chain, **Postgres-authoritative** template bodies — explicitly out of scope for Phase 17.
- **Per-operator custom template packs** on disk outside release — nice follow-up if solo users fork Kiln; not required for ONB-01.
- **Generated `index.json`** from filesystem for faster loads — optional optimization after MVP manifest.

### Reviewed Todos (not folded)

- None — `todo.match-phase` returned zero for phase 17.

</deferred>

---

*Phase: 17-template-library-onboarding-specs*  
*Context gathered: 2026-04-22*
