# Phase 8 — Technical Research

**Question:** What do we need to know to PLAN Operator UX (intake, ops, unblock, onboarding, global chrome) well?

**Sources:** `08-CONTEXT.md`, `07-CONTEXT.md`, `07-UI-SPEC.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `lib/kiln_web/router.ex`, `lib/kiln/specs.ex`, `lib/kiln/intents.ex`.

---

## 1. Bounded context correction (naming)

- **`Kiln.Intents`** in code = queued **run** requests (`enqueue/1`). **Do not** add inbox/draft CRUD here.
- **Inbox + drafts + GitHub import + follow-up generator** → **`Kiln.Specs`** (extend module + new `Kiln.Specs.*` schemas). Importer module: **`Kiln.Specs.GitHubIssueImporter`** (CONTEXT D-814, D-815).
- **Cost intelligence** extends **`KilnWeb.CostLive`** (tab/query param), not a separate top-level `CostIntelLive` process (D-802).

---

## 2. Ecto + idempotency patterns

- **Draft table** (`spec_drafts` or `inbox_items` — plan picks one name): states via **`Ecto.Enum`**, `archived_at` soft delete, `promoted_spec_id` nullable FK, GitHub **`node_id`** or `(owner, repo, issue_number)` partial unique index for open rows (D-818).
- **Promotion:** single transaction: state guard + insert `specs`/`spec_revisions` + link + **`Audit.Event`** (D-820).
- **Follow-up filing:** **`external_operations`** intent key `follow_up_draft:run_id:correlation_id` + audit `follow_up_drafted` same tx (D-817).

---

## 3. GitHub Issues API (Req, not shell)

- Use **`Req.get`** with URL built from validated owner/repo/number (no string interpolation from raw user paste without parsing).
- **`If-None-Match`** / ETag for refresh (D-819). Rate limits: surface `403`/`429` as card-level error with retry-after copy.

---

## 4. Onboarding gate (three layers)

1. **Router plug** — redirect to `/onboarding` when factory not ready; allowlist `/onboarding`, `/health`, static assets, `/ops/*` (D-807).
2. **Domain** — `Runs` / `RunDirector` rejects enqueue when probes fail (**authoritative**).
3. **`on_mount`** — banner only; never sole enforcement.

**Probes:** `gh auth status` (parse exit), Docker parity with `Kiln.Sandboxes` driver expectations, API key presence via **`persistent_term` / env refs** (SEC-01 — never persist values). Share probe helpers with **`Kiln.BootChecks`** where overlap (D-810).

**Escape hatch:** single env bypass family aligned with `KILN_SKIP_BOOTCHECKS` / auditable event (D-811).

---

## 5. PubSub cardinality (P16)

- **`factory:summary`** — low-rate aggregate (counts, spend rollup, provider RAG summary). Publisher debounces (e.g. 250–500 ms coalesce).
- **`agent_ticker`** — rate-limited fan-out; **not** wired to `run:#{id}` high-volume topics for header (D-821–824).
- **Ticker placement:** **`/` only** per roadmap SC 10 + D-823.

---

## 6. Unblock + notifications

- Reuse **`Kiln.Notifications`** from Phase 3 on block/escalation (D-830).
- **`UnblockPanelComponent`** in **`RunDetailLive`** when run state is **blocked** — typed reason + playbook lines from remediation module + **"I fixed it — retry"** → transition API already defined in `Kiln.Runs.Transitions` / worker (verify exact function name in implementation before coding).

---

## 7. Diagnostic snapshot (OPS-05)

- Server-side **zip** build: runs + configs + logs from last 60 minutes; **redaction pipeline** before write (regex + structured secret ref stripping); temp file + TTL; **download** via `send_download` or signed short-lived path (plan picks; document threat model for path guessing).

---

## 8. LiveView testing

- **`Phoenix.LiveViewTest`** + **`LazyHTML`**; assert stable IDs from UI-SPEC.
- For **`gh` / Docker** probes: **Mox** or exit-code injection at context boundary — CI must not require real `gh` login.

---

## Validation Architecture

> Nyquist / Dimension 8 — how execution proves each slice without human QA.

| Dimension | Strategy |
|-----------|----------|
| **Unit** | `Kiln.Specs` draft FSM, GitHub importer URL builder, redaction pure functions, probe result structs |
| **LiveView** | `inbox_live_test.exs`, `provider_health_live_test.exs`, `onboarding_live_test.exs`, extend `cost_live_test.exs` for intel tab, `run_detail_live_test.exs` for unblock + progress |
| **Integration** | Promotion transaction wraps audit insert; follow-up idempotency returns same draft id on duplicate intent |
| **Security** | No secret values in draft rows; diagnostic zip grep asserts redacted patterns; unblock events auth-guarded |

**Wave discipline:** After each plan wave, `mix test` scoped to touched test files; before phase close, `mix precommit` (project alias).

**Blocking migration task:** Any plan introducing `priv/repo/migrations/*.exs` must end with **`mix ecto.migrate`** (or CI-documented equivalent) before verification — Ecto is source of truth; types alone do not prove schema.

---

## RESEARCH COMPLETE
