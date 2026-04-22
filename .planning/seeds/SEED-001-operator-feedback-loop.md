---
id: SEED-001
status: parked
planted: 2026-04-18
planted_during: v0.1.0 / Phase 1 planning
trigger_when: Phase 9 verification OR v1 release-prep OR any future milestone involving self-evaluation / human-in-the-loop steering
scope: Medium-to-Large
---

# SEED-001: In-Flight Developer Feedback Loop

## Why This Matters

Kiln is a dark factory — autonomy is the whole point, and the scenario runner is the sole acceptance oracle. But in practice, real software has design decisions (UI direction, architectural tradeoffs, API shape, naming) where a one-line nudge from the operator mid-run would *meaningfully improve the outcome* without compromising autonomy.

Right now the feedback channels are all-or-nothing:
- `INTAKE-03` — file a follow-up spec *after* a PR lands (post-hoc)
- `BLOCK-01..04` — typed blocking reasons (credentials, auth, budget, escalation) — stops the run
- No middle ground: no way for the operator to say "I see what you're doing — that layout/naming/approach isn't quite right, here's a nudge" while the run keeps going.

Dark factories with zero steering produce *technically correct, subjectively wrong* output — the kind where the PR passes tests but feels off. The feedback loop closes that gap *without* re-introducing human-in-the-loop approval gates.

## When to Surface

This seed should auto-surface at:

- **Phase 9 verification** (late v0.1.0) — after Kiln dogfoods itself end-to-end, we'll have real data on whether subjective-wrongness is a problem worth solving.
- **Any v1.1+ milestone scoping** — especially if the milestone touches operator UX (Phase 7/8 analogs), the self-evaluation cluster, or model-routing improvements.
- **First customer/user complaint about output quality** — a real signal that nudges are needed.
- **Post-v1 retrospective** — natural checkpoint to decide whether this is v1.1 or v2.

## Scope

**Medium-to-Large.** Not a single-phase addition — this touches:

- **Data layer** (Small): new `operator_feedback_received` audit event kind + new optional column or JSONB field on `external_operations` or a new `operator_feedback` table.
- **Runtime layer** (Medium): each stage checks for unread feedback before consuming context; feedback text becomes part of the next prompt with explicit weighting ("operator nudged: ...").
- **UI layer** (Medium): LiveView surface showing "what Kiln is doing right now" with screenshots/diffs/summaries + a one-line feedback input. Must feel async (poll-style), not interrupt-driven.
- **Channel layer** (Small): osascript notification (already in `op_kind` D-17), optional Slack/Discord webhook for out-of-band nudge.
- **Model-context layer** (Medium): decide how much weight operator feedback carries vs scenario-runner verdict (always advisory, never override).

## Sub-themes (from `01-CONTEXT.md` lines 238–260 + this expansion)

The "Self-Evaluation Loop" cluster already captures 7 sub-themes. This seed adds an 8th:

1. Run post-mortem record (token usage, wall time, retries, model breakdown) — existing
2. Operator subjective rating after merge (1–5 + free text) — existing
3. Aggregated insights view across N runs — existing
4. Spec-to-result LLM-judge quality scoring (advisory only) — existing
5. Model bake-off workflow (new model vs old) — existing
6. Kiln-builds-Kiln dogfood feedback loop (recursive) — existing
7. External signal capture (CI outcomes, bug reports, runtime telemetry) — existing
8. **In-flight async operator nudges (THIS SEED)** — steering feedback mid-run, non-blocking

## Relationship to existing scope

- **Distinct from `INTAKE-03`:** INTAKE-03 is post-PR ("file as follow-up"). This is intra-run ("nudge while building").
- **Distinct from `BLOCK-01..04`:** Blocks stop the run; nudges don't.
- **Reinforces `UAT-01/02`:** Scenario runner remains sole acceptance oracle. Nudges are advisory soft-context, not gates.
- **Consumes `kiln-brand-book.md` voice:** the nudge UI uses operator microcopy ("Kiln is on: {stage}. Nudge? (optional)") — no chat-style prompting, no "AI magic."

## Breadcrumbs

- `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` lines 238–260 — original "Self-Evaluation Loop" v1.5 capture with the 7 sub-themes
- `.planning/REQUIREMENTS.md` — if formalized, this becomes `FEEDBACK-01` under the post-v1 cluster
- `.planning/PROJECT.md` Out of Scope — confirm that nudges remain *advisory* to honor "no synchronous human approval gates" constraint
- `.planning/research/ARCHITECTURE.md` §9 (audit ledger) — where `operator_feedback_received` event kind would land
- `prompts/kiln-brand-book.md` voice section — microcopy rules for the nudge UI
- `CLAUDE.md` Conventions § "Bounded autonomy" and "Typed block reasons, not chat" — design constraints: feedback must be structured, not freeform chat

## Concrete `FEEDBACK-01` candidate REQ

> **FEEDBACK-01:** During a run, Kiln periodically surfaces a lightweight "what I'm doing right now" summary (text + screenshot/video/diff/diagram depending on stage) via the operator UI or a notification channel. Operator can leave one-line async feedback that Kiln considers as *soft guidance* on subsequent stages — NOT a blocking approval gate (preserves dark-factory autonomy per UAT-01/02). Feedback is persisted as an `audit_events` row of kind `operator_feedback_received` alongside the run; subsequent runs and model-bake-offs can train on it. Distinct from `INTAKE-03` (post-PR follow-up) and from `BLOCK-01..04` (typed unblock). This is *steering*, not *gating*.

## Design open questions (for whoever plans this)

- How does Kiln weight operator feedback in prompt context? (Fixed weight? Recency-weighted? Tagged as `operator_hint` in the context object?)
- Does feedback propagate to future runs on the same workflow, or is it single-run scoped?
- Which stages surface a nudge prompt? (All? Or only UI/design-adjacent ones where subjective wrongness is likely?)
- UX cadence: every stage? Only when stage > N minutes? Only when operator is active in the UI?
- Multiple-operator support is v2 (PROJECT.md Out of Scope) — this is strictly solo-operator v1.

## Recommended next step when triggered

1. Run `/gsd-discuss-phase` for the containing phase (likely 9.x or a v1.1 phase).
2. Reference this seed file + `01-CONTEXT.md` lines 238–260 in the discussion log.
3. Decide whether `FEEDBACK-01` ships alone or alongside other Self-Evaluation Loop sub-themes.
4. If alone: plan as a decimal phase insertion. If alongside: plan as a full v1.5 milestone.
