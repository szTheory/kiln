# Phase 27: Local first-run proof - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `27-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-23
**Phase:** 27-local-first-run-proof
**Areas discussed:** Proof harness; Environment realism; Journey depth; Verification strictness
**Mode:** User selected **all** areas + requested parallel **subagent research** and one-shot cohesive recommendations.

---

## 1. Proof harness

| Option | Description | Selected |
|--------|-------------|----------|
| A — Focused LiveView command only | `mix test` over the existing first-run UI files | |
| B — Broader ExUnit suite | More files, one command, same app-layer realism | |
| C — Shell-only integration script | Extend `first_run.sh` into the full owning proof | |
| D — Thin Mix wrapper over existing SSOTs | One explicit proof command that delegates to machine smoke + focused UI proof | ✓ |
| E — `mix shift_left.verify` | Reuse the broad shift-left gate as the phase proof | |

**Selected:** **D — Thin Mix wrapper over existing SSOTs**
**Why:** Best DX and best honesty. It gives the repo one memorable command without hiding that the proof is intentionally two-layered: local machine bring-up plus focused Phoenix operator journey. It also matches existing repo command patterns better than pushing UI proof into shell or broadening Phase 27 into all-purpose shift-left coverage.

---

## 2. Environment realism

| Option | Description | Selected |
|--------|-------------|----------|
| L1 — Seeded/test-only realism | Purely ExUnit or seeded readiness | |
| L2 — LiveView test realism | Routed LiveViews only | |
| L3 — Real local topology | Compose data plane + host Phoenix + `.env` contract | ✓ |
| L4 — Browser/E2E ownership | Full browser path as the main proof | |

**Selected:** **L3 — Real local topology**, with **L2 retained as the app-behavior support layer**
**Why:** The milestone is local-first and operator-trust oriented. A proof that never boots the real local topology is too synthetic; a browser-owned proof is too expensive for the truth it adds in a LiveView-heavy app.

---

## 3. Journey depth

| Option | Description | Selected |
|--------|-------------|----------|
| A — Backend-only seam | Domain-layer start-run contracts only | |
| B — `/templates` happy path only | Phase 24-style proof carried forward | |
| C — Setup-ready operator happy path | `/settings` -> `/templates` -> `Start run` -> `/runs/:id` | ✓ |
| D — Full blocked detour ownership | Make unreadiness redirect/recovery the centerpiece | |

**Selected:** **C — Setup-ready operator happy path**
**Why:** It matches `UAT-04` literally and steps up from Phase 24 without widening into an overbuilt journey matrix. The blocked path remains important supporting coverage, but the phase-owned proof should be the ready-path story.

---

## 4. Verification strictness

| Option | Description | Selected |
|--------|-------------|----------|
| A — Stable ids + route outcomes | Operator-visible seams only | ✓ |
| B — Copy-heavy assertions | User text as main contract | |
| C — Deep domain-state assertions | DB/audit/run internals in the top-level proof | |
| D — Visual/screenshot ownership | Screenshots/snapshots as main proof | |
| E — Shell-only proof | Exit code / curl / logs without UI seam checks | |

**Selected:** **A — Stable ids + route outcomes**, with **minimal copy** and **shell assertions only at the outer integration boundary**
**Why:** This stays consistent with Phase 24, existing LiveView test style, and the broader Elixir/Phoenix ecosystem. It maximizes durability while keeping the proof meaningfully operator-facing.

---

## Subagent synthesis notes

- Phoenix/LiveView testing norms strongly favor `Phoenix.LiveViewTest` for routed server-rendered journeys and reserve browser automation for thinner top-layer coverage.
- Mature frameworks and tools consistently do better with **layered ownership** than with a single giant browser-owned “E2E” bucket.
- The strongest adjacent-product lesson came from CI/build systems like GitHub Actions and Buildkite: trust is built by landing the operator on one concrete run/build detail page with recent evidence near the top, not by forcing the dashboard to do all the proof work.
- The main footguns identified across the research were:
  - using a proof command that is broader than the claim it makes
  - moving server-rendered operator proof into shell or browser layers unnecessarily
  - duplicating app logic in wrappers instead of delegating to existing SSOTs
  - making copy or screenshots the primary contract

## Resulting recommendation

Phase 27 should ship one explicit Mix command that delegates to:

1. `mix integration.first_run`
2. `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs`

This is the smallest coherent recommendation set that is:
- honest about the real local machine story
- idiomatic for Phoenix/LiveView
- high-confidence without overfitting to browser flake
- aligned with Kiln’s UX story of `/settings` -> `hello-kiln` -> `/runs/:id`

---

*Append after future discuss revisions if CONTEXT is updated.*
