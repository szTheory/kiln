---
id: SEED-007
status: parked
planted: 2026-04-20
planted_during: v0.1.0 / Phase 3 planning (captured mid-session from operator)
trigger_when: Phase 8 intake UX (INTAKE-01..03) build OR v1.0 release-prep OR first non-primary operator struggles to write a good first spec OR any milestone touching "onboarding", "first-run experience", "spec authoring", or "project setup"
scope: Large
---

# SEED-007: Project Bootstrap Wizard — Lighthouse-Scored Prompt Builder for the First Spec

## Why This Matters

Kiln's output quality is a direct function of its input quality. A well-shaped initial project prompt — with clear architecture, stack, intent, constraints — produces crisp phases and clean runs. A vague initial prompt produces vague phases and expensive-to-fix drift.

Today the operator gets a blank textarea and has to be good at prompt engineering before they've ever seen Kiln run. That's the same problem SEED-003 (onboarding templates) addresses from the **canned-example side**, but SEED-003 doesn't help the operator who has a **novel project** that none of the templates fit. For those operators — which is most operators, most of the time — we need a guided path from "I have a rough idea" to "Kiln has a well-shaped project brief it can actually plan from."

The gap:
- Operator opens Kiln → blank spec box.
- Types a vague one-paragraph description.
- Kiln can't tell what language/framework/architecture they mean, guesses, and the first phase either over-scopes (planner generates 12 phases for what was supposed to be a script) or under-scopes (planner treats a Phoenix app like a bash one-liner).
- Operator fixes the first few phases manually, spends hours fighting misalignment, decides Kiln is "a lot of setup for the value."

What we need instead: a structured bootstrap flow that extracts the project's architecture, stack, intent, constraints, and success criteria from the operator in minutes, shows them a live-interpreted preview of what Kiln *heard*, scores the prompt's completeness, auto-fills gaps from sensible defaults, and only hands the operator a "Start first run" button when the brief is actually good enough to run.

## When to Surface

- **Phase 8 intake UX (INTAKE-01..03)** — this is the natural home. The blank spec editor in INTAKE-01 is exactly the artifact this seed improves.
- **v1.0 release-prep** — launch assets. A "blank box" first-run experience is not launchable. Either SEED-003 (templates) OR SEED-007 (wizard) must ship for v1 — ideally both, with templates as the fast path and wizard as the bespoke path.
- **First non-primary operator struggles with spec authoring** — the signal. If we watch someone type a spec and see them hesitating, deleting, second-guessing, that's the trigger.
- **Any milestone mentioning**: `onboarding`, `first-run experience`, `spec authoring`, `project setup`, `wizard`, `bootstrap`, `prompt builder`.

## Scope

**Large.** This is not a single phase — it's a multi-phase operator-UX initiative that compounds with other seeds.

### 1. The single-textbox MVP (Medium — ship first)

Start minimal. Textbox with live-interpreted structured output on the side. Operator types freeform. As they type (debounced ~500ms), an LLM call parses the text into structured fields:

```
Live-interpreted:
  Project kind:        Web application (80% confidence)
  Primary language:    TypeScript (detected: "React", "Next.js")
  Backend language:    Node.js (inferred from "API routes")
  Framework:           Next.js 14+ App Router (70% confidence)
  Database:            Postgres (detected)
  Auth:                ??? (not specified — will prompt)
  Deployment:          Vercel (70% confidence)
  CI/CD:               ??? (not specified — offer GitHub Actions default)
  Testing:             ??? (not specified — offer Vitest default)
  Intent:              "build a thing that..." — extracted goal summary
  Success criteria:    extracted from "it should..." phrases
  Constraints:         extracted from "must not / cannot / should avoid" phrases

Lighthouse score: 62/100
  ✓ Language identified
  ✓ Framework identified
  ✓ Intent clearly stated
  ⚠ Auth strategy missing
  ⚠ CI/CD not specified
  ⚠ No explicit success criteria
  ⨯ No stated constraints
  ⨯ No deployment target

Next suggestions (click to apply):
  [Add auth strategy]  [Pick CI/CD]  [Add explicit success criteria]
```

The lighthouse score is the UX anchor — borrows from Google Lighthouse's "you get an objective quality number, here's what's holding it back, here's how to fix it" pattern. Operator sees immediately that their prompt is at 62, can click three suggestions, score jumps to 88, they hit "Start first run" with confidence.

### 2. Presets for common architectures (Small — compounds with MVP)

For the 6-8 most common project shapes (Phoenix app, Rails app, Django app, Next.js app, FastAPI backend, CLI tool, Elixir library, TypeScript library), offer a one-click preset that fills in sensible defaults — the operator can override anything, but doesn't have to think about every dial from scratch. Each preset is a YAML stanza in `priv/presets/` with language/framework/test-runner/CI/deployment defaults.

Presets are NOT templates (SEED-003). Templates are "here's a canned spec for 'hello kiln'"; presets are "here's the architectural scaffold for *your* new Phoenix app — now tell us what it does."

### 3. Graphical detection panels (Medium — the "lighthouse feel")

Right-side visual panels that render detected structure:

- **Language & frameworks** — badges: `TypeScript 5+` · `Next.js 14` · `React 19` · `Tailwind` · `shadcn/ui`.
- **Architecture diagram** — simple boxes: `[Web UI] → [API routes] → [Postgres]`. Auto-generated from detected fields. Missing boxes are shown as dashed "???" placeholders with click-to-fill prompts.
- **CI/CD pipeline diagram** — same treatment: `[lint] → [test] → [build] → [deploy to Vercel]`. Dashed boxes for missing stages.
- **Success criteria checklist** — extracted as a checklist; operator can refine each item.
- **Budget & time estimate** — based on detected complexity, ModelRegistry presets, and historical run costs: "This looks like a ~$3–7 / 8–15 minute first run."

These panels turn the text-box-wall-of-text into a **visualization of what Kiln understands** — the operator's mental model stays in sync with Kiln's, in real-time. Mental-model mismatch is the single biggest cause of "Kiln produced something I didn't want."

### 4. Suggest-and-apply flow (Medium — the interactive loop)

Instead of "fill out 40 form fields," the wizard surfaces 3-5 highest-value suggestions at a time and the operator clicks-to-apply. Each application updates the prompt text **visibly** so the operator sees exactly what changed (diff-highlighted); they can undo any single suggestion without discarding the rest. This is the ambient prompt-improvement loop — the wizard never silently rewrites.

### 5. Score methodology (Small — but must be principled)

The lighthouse score is:
- **50%** structural coverage: how many of the ~12 "what Kiln needs to plan" fields are filled (language, framework, arch, success criteria, constraints, CI/CD, deployment, testing, budget cap, etc.).
- **25%** specificity: fields filled with concrete values vs. vague ones ("should be fast" = vague; "p99 API response < 200ms" = specific).
- **15%** consistency: detected fields don't contradict (e.g., "Python CLI" + "Next.js deployment" = red flag).
- **10%** stated constraints: explicit mentions of what *not* to do; these dramatically reduce false-positive agent work.

Score thresholds:
- **0-40:** "Kiln can't plan from this yet." Block the "Start run" button.
- **40-70:** "Kiln can plan but will ask a lot of questions / may drift." Allow with a warning.
- **70-100:** "Good to go." Green "Start first run" CTA.

Scoring is stable across sessions — a given prompt always produces the same score (modulo LLM nondeterminism in the parser). We want operators to feel they're steering something objective, not placating a mood ring.

### 6. Persistence into PROJECT.md (Small but load-bearing)

At the end of the wizard, the structured output is written to `.planning/PROJECT.md` (overwriting or migrating from the current `/gsd-new-project` output) — so the wizard **replaces** the slash-command + Socratic-questioning path for first-time project setup. Existing `/gsd-new-project` becomes the power-user / scriptable alternative; the wizard becomes the default onboarding.

The PROJECT.md that comes out of the wizard should be at least as rich as the hand-authored one, which means: the wizard's LLM pass has to be tuned to extract decisions, constraints, and success criteria in the same shape that `/gsd-new-project` produces today. Use existing PROJECT.md files as few-shot examples.

### 7. Returning-operator experience (Small)

Once a project exists, the wizard can be re-entered at any time to *update* the PROJECT.md: add a new milestone, revise constraints, pivot the stack. Same live-interpreted + lighthouse-scored flow, but prefilled from current PROJECT.md and showing a diff. This replaces `/gsd-new-milestone` for most operators too.

## Relationship to existing scope

- **INTAKE-01..03 (Phase 8)** — the wizard is the front-end of INTAKE-01. Everything downstream (inbox, triage, promotion) still works; the wizard just produces a much better spec draft.
- **SEED-003 onboarding templates** — complementary. Templates = "I want a canned example"; wizard = "I have a novel project." Both paths converge on "a well-shaped PROJECT.md the planner can use."
- **SEED-006 external reference codebases** — the wizard is the natural place to attach reference repos. "You mentioned 'like Phoenix's controller pattern' — want to attach phoenixframework/phoenix as a reference?" is a wizard prompt, not a config-file edit.
- **Existing `/gsd-new-project` command** — the wizard is a GUI replacement for this slash command's Socratic questioning flow. The underlying PROJECT.md shape stays the same; the acquisition UX changes.
- **Brand contract (CLAUDE.md)** — restrained, precise, calm. Lighthouse score is objective and terse. No "AI magic" copy. The score numbers themselves do the emotional work.
- **PROJECT.md Core Value — "Given a spec, Kiln ships working software"** — this seed is literally about making the spec good enough that Kiln can ship from it.
- **P2 pitfall (cost runaway)** — a 62→88 lighthouse score IS a cost-runaway mitigation; vague prompts produce more retries and drift, which burns tokens. Better prompts are cheaper runs.

## Design open questions

- **How opinionated are the presets?** Ship 6 or 12? Fewer presets = sharper quality; more presets = broader fit. Lean toward fewer.
- **Should the live interpretation LLM call use Kiln's own budget-guarded adapter?** Yes — eat our own dog food. But the per-call budget must be tiny (this is a UX loop, not a planning pass).
- **Privacy / telemetry** — if the wizard's LLM parses prompts server-side (e.g., cloud-based Claude call), that's a subtle privacy surface. Local-first operators might want an "everything stays on my machine" flag that downgrades to a smaller local Llama model for the parse. Worth designing around.
- **Lighthouse score calibration** — what prevents an operator from gaming the score by stuffing boilerplate to hit 90+? Probably: the score's "specificity" component penalizes generic phrases. A 100/100 score should require both coverage AND specificity.
- **Where does the wizard UI live?** LiveView at `/new-project` URL? Separate `kiln new` CLI command with TUI? Both? Probably both: LiveView for interactive operators, CLI TUI for scripted/programmatic bootstrap.
- **Can the wizard be re-run on an existing project to "upgrade" a weak PROJECT.md?** Yes (item 7 above). This is also how we migrate v0 → v1 PROJECT.md shapes when the shape evolves.
- **Handoff to `/gsd-new-project`?** The wizard's output could be piped directly into `/gsd-new-project` as its input, or it could replace `/gsd-new-project` entirely. Leaning: wizard writes PROJECT.md directly; the slash-command path remains as a fallback for automation / scripting / CI use.
- **Team-vs-solo** — PROJECT.md explicitly scopes out multi-tenant/SaaS for v1. Wizard should not introduce "invite collaborator" UX; it's for a single operator bootstrapping a single project. Revisit if multi-tenant lands post-v1.

## Breadcrumbs

- `.planning/REQUIREMENTS.md` INTAKE-01 (Phase 8) — the blank-textarea entry point this seed improves.
- `.planning/REQUIREMENTS.md` INTAKE-02 (Phase 8) — the inbox receives wizard output as a spec draft.
- `.planning/REQUIREMENTS.md` DOCS-03 — "Workflow & spec authoring guide" — wizard supplants most of what this guide would teach.
- `.planning/ROADMAP.md` Phase 8 (intake UX) — natural home.
- `.planning/PROJECT.md` — the artifact the wizard writes; shape already established.
- `$HOME/.claude/get-shit-done/workflows/new-project.md` — the Socratic-questioning flow this seed replaces for GUI users.
- `SEED-003 onboarding templates` — complementary first-run path.
- `SEED-006 external reference codebases` — wizard is the natural attach point for references.
- `SEED-001 in-flight feedback loop` — post-run feedback compounds with pre-run bootstrap: tight loops at both ends of the run.
- `prompts/kiln-brand-book.md` — calm/precise/restrained voice for wizard microcopy.

## Recommended next step when triggered

1. **Sketch phase** — run `/gsd-sketch` with the single-textbox MVP + right-side lighthouse panel as the first throwaway mockup. Validate the interaction feel before committing to full scope.
2. **Preset library** — hand-author 6 presets for common project kinds; iterate until each produces a runnable PROJECT.md the planner is happy with.
3. **Live-interpret prompt tuning** — the LLM call that extracts structure must be faster than 1s p95 to keep the typing loop responsive; needs its own model-routing preset (likely Haiku with a tight schema constraint).
4. **Ship the MVP first (item 1 in Scope), then graphical panels (item 3), then suggest-and-apply (item 4)** — each layer is independently useful; don't build all three before shipping.
5. **Reserve `/gsd-new-project` and `/gsd-new-milestone` as power-user fallbacks** — the wizard is the default, but the slash commands stay for automation. Don't rip them out.
6. **Measure post-ship:** operators who come through the wizard → run-success-rate vs. operators who come through blank textarea → run-success-rate. If wizard doesn't lift success rate by at least 20 percentage points, the score methodology (Scope item 5) needs recalibration.
