# Phase 22: Merge authority & operator docs - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **DOCS-08**: operators and contributors share **one honest story** of what **GitHub Actions** must prove before merge vs what is **optional local smoke** (Postgres, Docker, Dialyzer, OTel, fixtures). Surfaces live in **`README.md`** and **`.planning/PROJECT.md`** (the repo’s `PROJECT.md` SSOT path per existing layout — there is no root `PROJECT.md`).

**Success criteria (from ROADMAP):** (1) README and PROJECT carry the **same policy** — satisfied by **one canonical matrix** in `PROJECT.md` plus a **short README summary + stable link** (no duplicate authoritative tables). (2) **Phase 12** partial local verification is **referenced by fact**, not hidden.

**Out of scope for this phase:** NYQ-01 / UAT-03; redesign of CI jobs themselves; new workflows unless planning discovers a missing doc link only.

</domain>

<decisions>
## Implementation Decisions

### D-2201 — SSOT placement (README vs PROJECT)

- **Canonical merge-authority content** lives in **`.planning/PROJECT.md`** under a **single stable heading** (implementer picks exact slug; example: `## Merge authority`). That section holds the **tiered table** + **Local vs CI** bullets below it. **One edit surface** for policy + CI drift control.

- **`README.md`** carries a **compact, non-authoritative** block (target **3–6 lines**): state that **green GitHub Actions checks on PRs to `main`** are merge authority; link to **`.planning/PROJECT.md#<anchor>`** for the full matrix. **Do not** paste a second full matrix in README.

- **Rationale (research synthesis):** Duplicate tables are a default drift footgun (OSS norm: Phoenix/Ecto README → guides/Hexdocs; Rails/CONTRIBUTING single normative home). `PROJECT.md` already anchors product + requirements; merge policy belongs next to **trust** and **constraints**. README stays idiomatic **orientation + badges + quick start** (Phase 21 **D-2101** spirit: one first-success path, not a second competing “law” block).

### D-2202 — Table shape: tiers vs one-row-per-job

- Use a **small tiered table** (**3–5 rows max**) describing **semantic merge tiers**, not one row per Actions step or matrix permutation.

- **Suggested tier mapping for current `.github/workflows/ci.yml`:**  
  - **Tier A — PR merge gate (Elixir/Postgres):** `check` job → `mix compile --warnings-as-errors`, **`mix check`**, same Postgres service contract as CI.  
  - **Tier B — Durability / DB invariants:** dedicated step **`KILN_DB_ROLE=kiln_owner mix ecto.migrate && mix kiln.boot_checks`** (same job as today — can be one row with the step named explicitly).  
  - **Tier C — Compose + integration smoke:** `integration-smoke` job → `test/integration/first_run.sh` (after `check`).  
  - **Tier D — Tag / release hygiene (conditional):** `tag-check` job on `v*` tags only — label as **not every PR**.

- Add a **Workflow reference** column (or footnote row): path **`.github/workflows/ci.yml`** + **job `name:`** strings so contributors can match the Checks UI without the doc mirroring every future YAML refactor.

- **Path-filtered or optional jobs** (e.g. future Phase 21 Docker build): document **merge vs advisory** and **when a check may not appear** on a PR (avoid “optional” ambiguity and branch-protection “pending forever” footguns).

- **Rationale:** Elixir core and mature OSS favor **intent + link to workflow** over mirroring CI matrices; solo-maintainer projects under-maintain long per-job tables. **Felt ultimate-elixir-ci**-style separation of **nightly / expensive** vs **PR gate** is the model when more jobs appear.

### D-2203 — Optional local commands vs merge table

- **Merge-authority table rows = only what CI enforces on merge** (blocking tiers above). Language: **“Required on PR (GitHub Actions)”** or equivalent — never imply `just` / `mix precommit` / docs verify are merge gates unless added to branch protection.

- **Immediately below** the table in the same `PROJECT.md` section, add **“Recommended before push (optional, not merge authority)”**: bullet list of **`just planning-gates`**, **`just shift-left`**, **`script/precommit.sh` / `mix precommit`**, **`DOCS=1 mix docs.verify`**, and any **dogfood** / scenario pointers — **one line each** + what failure class it catches. README may **repeat only the single best-effort local command** that approximates Tier A (e.g. `mix check` with env caveats) **or** link to PROJECT for the list — **no** mixing optional rows into the merge table without a **Required in CI** column (avoid that pattern).

- **Rationale:** Pre-commit / CONTRIBUTING patterns worldwide: **CI = oracle**, optional = faster feedback. Clear cognitive model for new contributors vs operators (Phase 12/21 `just` catalog stays discoverable without polluting merge law).

### D-2204 — Phase 12 PARTIAL + “local vs CI” narrative

- **README:** **One short callout** near the quick start / verification story (not above-the-fold wall of text): local runs (including historical **Phase 12** plan verification) may report **PARTIAL** for `mix check` when Postgres, env, or strict tools differ from CI; **merge requires green GitHub checks on the PR.** Link to **`.planning/phases/12-local-docker-dx/12-01-SUMMARY.md`** (Verification log / deviations — factual, not shamey) **and** to **`.planning/PROJECT.md#merge-authority`**.

- **`PROJECT.md` merge section:** include a **“Local vs CI”** subsection: what CI guarantees; what local scripts **approximate**; common mismatch causes (DB down, Docker missing, `MIX_ENV`, OTP/Elixir drift). Tone: **calm, competent** (Rust rustc-dev-guide / Cargo CI chapter style): mismatch is **normal surface area**, not “CI is broken.”

- **Rationale:** Two-layer pattern (README skim + deep truth) matches Rust, Postgres layered verification, K8s tiered tests — maximizes **trust in CI** while **honoring** Phase 12’s documented reality.

### D-2205 — Cohesion with prior phase locks

- **Phase 12 (D-1202, D-1204):** README remains the **canonical quick start**; merge-authority work is an **additive** policy island + callout — does not replace operator checklist structure. **`mix check`** stays described as the **core** of Tier A; no second full `mix check` inside Docker on every PR.

- **Phase 21 (D-2101, D-2114):** Optional Dev Container / `just` paths stay **tiered below** canonical host path; **full merge authority remains GitHub Actions** as today.

### Folded todos

_None — `todo.match-phase` returned no matches._

### Claude's discretion

- Exact **Markdown heading** / anchor slug for `PROJECT.md`.  
- Whether to add a **GitHub PR template** one-liner pointing at merge authority (improves discovery; **not** required by DOCS-08).  
- Table column titles and row ordering once `ci.yml` is re-read at implementation time.  
- Whether **CONTRIBUTING.md** gets a **duplicate short pointer** to the same anchor (nice for GitHub “Contributing” tab; optional).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **DOCS-08** (merge authority matrix; Phase 12 honesty; `12-01-SUMMARY.md` citation).
- `.planning/ROADMAP.md` — Phase 22 goal and success criteria.

### Prior decisions (do not contradict unless this CONTEXT explicitly does)

- `.planning/phases/12-local-docker-dx/12-CONTEXT.md` — D-1201–D-1205; README canonical quick start; `mix check` CI gate.
- `.planning/phases/12-local-docker-dx/12-01-SUMMARY.md` — Verification log documenting **local `mix check` PARTIAL** vs **CI merge gate** (evidence for honest wording).
- `.planning/phases/21-containerized-local-operator-dx/21-CONTEXT.md` — D-2101, D-2114 (README anchor; `mix check` authoritative).

### Mechanical truth (must match prose)

- `.github/workflows/ci.yml` — Jobs `check`, `integration-smoke`, `tag-check`; steps `mix check`, `mix kiln.boot_checks`, `first_run.sh`.

### Ecosystem patterns cited during research (external)

- [Phoenix CONTRIBUTING](https://github.com/phoenixframework/phoenix/blob/main/CONTRIBUTING.md) — local `mix test` expectation + env in bug reports.  
- [Elixir CONTRIBUTING](https://github.com/elixir-lang/elixir/blob/master/CONTRIBUTING.md) — local commands + workflow truth.  
- [Rust CI testing](https://rustc-dev-guide.rust-lang.org/tests/ci.html) — staged coverage; CI authoritative.  
- [Cargo book — Continuous Integration](https://doc.rust-lang.org/cargo/guide/continuous-integration.html) — optional jobs / tradeoffs.  
- [Felt ultimate-elixir-ci README](https://github.com/felt/ultimate-elixir-ci/blob/main/README.md) — conceptual CI grouping + badges.

</canonical_refs>

<code_context>
## Existing Code Insights

### CI integration points

- **`.github/workflows/ci.yml`:** `check` (Postgres service + `mix check` + `mix kiln.boot_checks`), `integration-smoke` (`first_run.sh` after `check`), `tag-check` (tags only). Doc rows must stay aligned with these **job names** and **step commands**.

### README / operator docs

- **`README.md`:** CI badge, quick start, **Optional: Just recipes** table (`planning-gates`, `shift-left`, `precommit`), integration/dogfood table — merge callout should **not** duplicate the whole Just table; **link** to PROJECT for policy.

### Scripts

- **`script/planning_gates.sh`**, **`script/shift_left_verify.sh`**, **`script/precommit.sh`** — belong under **recommended optional**, not merge table, unless CI is changed to run them verbatim on every PR.

</code_context>

<specifics>
## Specific Ideas

- User requested **parallel subagent research** across all four gray areas and a **single coherent** recommendation set; decisions above consolidate that research with Kiln’s **solo operator**, **scenario-runner / CI honesty**, and **Phase 12/21** locks.

</specifics>

<deferred>
## Deferred Ideas

- **CONTRIBUTING.md** as primary SSOT for merge policy (GitHub Contributing tab UX) — **deferred**; DOCS-08 names `PROJECT.md`; optional later if maintainers want dual entry with one link.

- **Auto-generated check list from YAML** — powerful anti-drift tooling; **deferred** (out of scope unless a later phase adopts codegen docs).

- **None** — discussion stayed within phase scope.

</deferred>

---

*Phase: 22-merge-authority-operator-docs*
*Context gathered: 2026-04-22*
