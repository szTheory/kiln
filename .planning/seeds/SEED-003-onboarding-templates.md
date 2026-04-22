---
id: SEED-003
status: parked
planted: 2026-04-18
planted_during: v0.1.0 / Phase 1 execution (captured mid-run from operator)
trigger_when: Phase 9 dogfood complete OR v1.0 release-prep OR first time someone other than the primary operator runs Kiln
scope: Small-to-Medium
---

# SEED-003: Vetted Onboarding Template Library

## Why This Matters

Kiln's whole pitch is "feed it a spec, it ships software." For a new operator, that pitch is only credible if they can *see it work end-to-end* within their first 10 minutes. The operator shouldn't have to write a good spec from scratch on day one — that's asking them to be good at Kiln before they've ever seen Kiln run.

The onboarding gap:
- New operator opens Kiln → sees an empty dashboard and a blank "spec" textarea.
- Writes a first spec that's too vague or too ambitious → Kiln either escalates (bad first impression) or produces low-quality output (also bad first impression).
- Decides Kiln "doesn't work" before giving it a real shot.

A vetted template library closes this gap: "Here are 5 pre-written specs that we have personally run through Kiln end-to-end and know produce shipped software. Pick one, click Run, watch the factory crank."

## When to Surface

- **Phase 9 dogfood** — once Kiln has actually built something, we know which spec styles work. Time to codify 3–5 of them as templates.
- **v1.0 release-prep** — templates are a critical launch asset. Without them, the first-run experience is "stare at an empty box."
- **First time a non-primary operator (friend, collaborator, demo audience) touches Kiln** — they will ask "what should I type?" before doing anything. Templates answer that.

## Scope

**Small-to-Medium.** The library itself is small (a handful of curated specs + workflow configs); the surrounding UX is what makes it shine.

### 1. Template format (Small)
- Each template is a `spec` + `workflow` + optional `seed_context` (README, existing-code-snippet, design-doc reference).
- Stored in `priv/templates/` (or `.kiln/templates/` if we want operator-editable) as YAML/Markdown pairs.
- Frontmatter: `name`, `description`, `estimated_run_time`, `estimated_cost_usd`, `expected_output`, `model_requirements`.

### 2. Library contents (Medium — content curation is the real cost)
Candidate templates we'd vet and ship (exact list TBD after Phase 9):
- **"Hello Kiln"** — a trivial CLI that reads a file, transforms it, writes output. Exercises the happy path end-to-end in ≤5 minutes / ≤$0.20.
- **"REST API + one endpoint"** — Phoenix/Plug/FastAPI/Express single-endpoint API with tests. Exercises scaffolding + routing + test gen.
- **"Refactor this code"** — operator pastes a code snippet; Kiln refactors for readability/perf, runs the existing tests. Exercises modify-existing-code flow.
- **"Fix this failing test"** — operator pastes a failing test + the module; Kiln diagnoses and fixes. Exercises debug flow.
- **"Add a feature to this repo"** — operator points at a public GitHub repo (read-only) + feature description; Kiln produces a PR. Exercises full scenario runner.

Each template:
- Has been run through current Kiln end-to-end at least twice, by the primary operator.
- Has a recorded "expected output" + "typical run time" + "typical cost" in its frontmatter.
- Has a short 30-second demo video/GIF attached (nice-to-have, not required for v1).

### 3. UX surface (Small)
- Dashboard: "New run → from template" chooser showing the 3–5 templates as cards.
- Card shows: name, 1-line description, expected cost + time, "Run" button.
- Clicking Run prefills the spec + workflow, operator tweaks if desired, clicks "Start run."
- Marketing-site equivalent on the docs/landing site (backlog 999.1) — same templates, download-as-spec link, "try it locally" CTA.

### 4. Maintenance discipline (Medium, ongoing)
- Templates MUST be re-run before every Kiln release to catch regressions. "My template used to work; now it escalates" is a real failure mode.
- CI job: run template smoke tests against the latest Kiln build; produce pass/fail + cost-drift report. If a template starts failing, that's a release-blocker.
- Each template has an explicit "last verified" date in its frontmatter + a pointer to the run/PR that verified it.

## Relationship to existing scope

- **Complements 999.1 docs + landing site** (already in backlog) — templates are the headline asset of the landing site.
- **Complements SEED-002** (remote operator) — remote kickoff from phone is MUCH more compelling when the phone UI is a template chooser, not a blank spec editor.
- **Depends on Phase 9 dogfood** — we can't claim templates are "vetted" if we haven't watched Kiln run them. This is Phase 9's output, promoted into a curated library.
- **Reinforces PROJECT.md core value** ("Given a spec, Kiln ships working software with no human intervention") — templates are the most direct demonstration of that value prop.
- **Honors "bounded autonomy"** (CLAUDE.md) — templates come with explicit cost + retry + model caps so first-run operators don't accidentally burn $50 on a "hello world."

## Breadcrumbs

- `.planning/ROADMAP.md` 999.1 — docs + landing site is the natural home for templates' public-facing surface.
- `.planning/phases/09-*` (future) — the dogfood phase is where templates are vetted end-to-end.
- `.planning/PROJECT.md` Core Value + Persona — templates directly serve the "solo engineer wants to see this work" need.
- `prompts/kiln-brand-book.md` — template names and descriptions stay in the calm/precise/restrained voice; no "Try our AI magic demo!" marketing tone.
- `CLAUDE.md` Conventions "Scenario runner is the sole acceptance oracle" — templates ship with scenario-runner-compatible acceptance tests, so the "is this run successful?" answer is mechanical.

## Design open questions

- Are templates shipped in-repo (`priv/templates/`) or fetched from a Kiln-owned registry (`templates.kiln.dev`)? In-repo is simpler and offline-capable; registry enables updates without new Kiln releases.
- How many templates in v1? 3 (curated, very high quality) vs 10 (broader coverage, more maintenance burden)? Recommend 3–5.
- Do templates support variable substitution? (`"Build a CLI that {{does_what}}"` — operator fills `does_what` in a form.) Nice UX win, adds scope.
- Licensing: are the templates themselves CC0 / public-domain? Probably yes — they're meant to be freely remixed.

## Recommended next step when triggered

1. After Phase 9 dogfood lands, gather the 3–5 specs that worked best into `priv/templates/`.
2. Write each template's frontmatter with honest cost + time estimates from real runs.
3. Add a "Templates" section to the dashboard and the docs/landing site.
4. Set up the CI smoke-test job to re-run templates before every release.
5. Re-surface SEED-002 if remote kickoff is the next milestone — templates + remote kickoff compound.
