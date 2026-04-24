# Phase 3: Agent Adapter, Sandbox, DTU & Safety - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 03-CONTEXT.md — this log preserves the alternatives considered + research findings.

**Date:** 2026-04-20
**Phase:** 03-agent-adapter-sandbox-dtu-safety
**Areas discussed (all 4):** Adapter scope + registry + streaming; Sandbox image + limits + workspace + Docker options; DTU mock scope + generation + hosting; Secrets + block reasons + BudgetGuard
**Mode:** User requested "research using subagents, think deeply one-shot a perfect set of recommendations". All 4 gray areas routed to parallel `gsd-advisor-researcher` agents (4 concurrent), each producing: option comparison tables, Elixir/Phoenix idiomaticity analysis, cross-ecosystem lessons (right + wrong + footguns), DX emphasis, coherent one-shot recommendations, and canonical refs. Synthesis presented to user; user approved all 16 sub-decisions as-is ("approve b/c we'll research next anyways").

---

## Gray Area 1 — Adapter Scope, Model Registry & Streaming

**Sub-areas decided:** (1a) Adapter scope, (1b) Streaming depth, (1c) Structured output strategy, (1d) Model registry depth & fallback.

### (1a) Adapter Scope

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. Anthropic live + OpenAI/Google/Ollama scaffolds (Mox-tested, `@tag :live_*`) | Behaviour polymorphism actually exercised; matches `instructor_lite`; ROADMAP literal read | 3x module count; scaffold-rot risk if deferred | ✓ |
| B. All 4 live + CI integration | Max confidence | Burns CI budget; CI secrets on public repo; violates bounded-autonomy spirit at infra level | |
| C. Anthropic only, defer others to P5 | Smallest surface | Behaviour untested as polymorphism contract; SC #3 theoretical until P5 | |

**Rationale:** Option A matches ROADMAP literal + `instructor_lite`'s proven Elixir pattern. Cross-ecosystem footgun to avoid: LangChain-Python / LiteLLM's "mirror every provider param" bloat. Kiln's 4-callback surface (`complete/stream/count_tokens/capabilities`) is deliberately tighter.

### (1b) Streaming Depth

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. `complete/2` live; `stream/2` raises `:not_implemented` | Zero speculative PubSub topology | Anthropix already gives streaming for free — leaving it on floor; callback documented but unused | |
| B. Full stream + PubSub + telemetry now | Ready for P4/P7 | Commits PubSub topic shape before P4/P7 have named needs; LV has no built-in backpressure (confirmed Hex Shift writeups) | |
| C. Return `{:ok, Enumerable.t()}` passthrough + `[:kiln,:agent,:stream,:chunk]` telemetry, no PubSub | Honest implementation; Anthropix lazy Enumerable flows through; demand-driven backpressure; zero premature topology | Consumer owns process boundary | ✓ |

**Rationale:** LiveView has no built-in backpressure primitive (confirmed per Hex Shift writeup + `stream_async` docs) — committing PubSub shape in P3 commits backpressure *policy* without a consumer to calibrate against. `langchain_elixir` `on_llm_new_delta` is our reference shape for P7.

### (1c) Structured Output Strategy

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. Unified `Kiln.Agents.StructuredOutput` facade + per-provider native modes + JSV defense-in-depth | Native modes beat raw-JSON-retry post mid-2025 (Mastra 15%→3% error reduction); `instructor_lite` proven shape | 3 native code paths | ✓ |
| B. Raw JSON + JSV + retry with corrective prompt | One code path | Burns tokens on reprompt; weaker than native constrained decoding | |
| C. Skip in P3; raw text out | Zero new surface | SC #1 telemetry still works but planner role can't return structured plans | |

### (1d) Model Registry Depth & Fallback

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. All 6 presets live + same-provider tier cascade + audit-only tier-cross warning | SC #5 literal compliance; OpenRouter/LiteLLM ordered-fallback pattern; `fallback_policy` field reserved for P5 cross-provider flip with zero schema migration | Notifications for tier-cross deferred to P7 | ✓ |
| B. 2-3 real presets + 3 aliased | Less drift surface | Violates SC #5 "selecting phoenix_saas_feature resolves deterministically" | |
| C. All 6 + cross-provider fallback + desktop notification now | Most feature-complete | Cross-provider impossible until OpenAI live; Notifications pulls P7 scope forward | |

**User's choice:** All 4 sub-decisions selected (A, C, A, A) per research agent's coherent one-shot recommendation.
**Notes:** User explicitly stated "approve b/c we'll research next anyways" — accepts that `/gsd-research-phase 3` will validate exact preset role→model mappings + pricing tables.

---

## Gray Area 2 — Sandbox Image, Resource Limits & Workspace Mount

**Sub-areas decided:** (2a) Base image strategy, (2b) Resource limits, (2c) Workspace mount & diff capture, (2d) Sandbox Docker option set.

### (2a) Base Image Strategy

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. Per-language Dockerfile, Elixir-first (hexpm/elixir:1.19.5-erlang-28.1.1-alpine-3.21) | Small + predictable; each language cached independently; dogfood-path clear; fast cold-start | N dockerfiles to maintain | ✓ |
| B. Universal image + tool-pack overlay | Single image cache | 5-10GB image; slow first-pull pain at 2am | |
| C. Minimal base + install-at-stage | Smallest images | Cold-start install on every stage; fights egress-block posture | |
| D. Hybrid tiny base + pre-pulled language layers | Layer-cache sharing | Extra indirection without benefit until >2 languages | |

### (2b) Resource Limits

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. Conservative uniform (512m / 1cpu / 200 pids / nofile=1024) | Tight blast radius | `mix compile` peaks >512MB (elixir-lang#12141); false-positive OOMKilled on real builds | |
| B. Permissive uniform (2g / 2cpu / 512 pids / nofile=65535) | No friction; matches typical CI | 4 × 2g = 8g baseline exhausts Docker Desktop VM | |
| C. Adaptive per-stage-kind via `priv/sandbox/limits.yaml` (planning/verifying conservative, coding/testing/merge permissive) | Matches actual workload shape; host-footprint-aware; YAML-configurable; policy-shaped-not-number-locked | One more config file | ✓ |

**Rationale:** Explicit research-flag defer on exact numbers. Policy shape locked here; numbers validated during `/gsd-research-phase 3` via live measurement against a real Phoenix project.

### (2c) Workspace Mount & Diff Capture

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. RO-in + WO-out via CAS (artifact_ref as sole handoff) | Honors D-75 primitive; kills P19 drift architecturally; defense-in-depth vs P5 (no git in container); Dagger-proven pattern | Heavier plumbing at stage boundary | ✓ |
| B. RW scratch + `git diff` at exit | Simple mental model | Git ops inside container (P5 surface expansion); binary artifacts lost; P19 drift returns via shared scratch | |
| C. Persistent per-run worktree | Fast stage chaining | Maximum P19 exposure; replay ambiguity | |

### (2d) Docker Option Set

**Adopted every container:** `--rm --network kiln-sandbox --cap-drop=ALL --security-opt=no-new-privileges --security-opt=seccomp=default --read-only --tmpfs /tmp:rw,noexec,nosuid,size=<limits> --tmpfs /workspace:rw,nosuid,size=<limits> --tmpfs /home/kiln/.cache:rw,nosuid,size=<limits> --user 1000:1000 --memory=<K> --memory-swap=<same> --cpus=<K> --pids-limit=<K> --ulimit nofile=4096:8192 --ulimit nproc=<K> --stop-timeout 10 --label kiln.run_id=<id> --label kiln.stage_run_id=<id> --label kiln.boot_epoch=<monotonic_ms> --label kiln.stage_kind=<atom> --env-file <per-stage-envfile-from-allowlist> --hostname kiln-stage-<short> --workdir /workspace --init --dns <DTU_IP> --add-host api.github.com:<DTU_IP> --sysctl net.ipv6.conf.all.disable_ipv6=1`.

**Rejected:** rootless Docker (Desktop macOS networking caveats; Phase 9 hardening), `--userns-remap`, Linux-only `apparmor` (Phase 9 conditional), custom seccomp JSON (tuning pit), Kata/gVisor/Firecracker/Docker Sandboxes microVM (overkill v1), `--privileged`, any arbitrary `-v /var/run/docker.sock:...`, arbitrary host bind-mount of workspace.

**DNS-block enforcement (SC #2):** 5 layers documented in D-119.
**Orphan cleanup:** `Kiln.Sandboxes.OrphanSweeper` at boot, BootChecks 8th invariant, `MuonTrap.cmd/3` wraps `docker run` for BEAM-crash subprocess-tree cleanup.

**User's choice:** A, C, A, hardened-option-set-adopted per research agent recommendation.

---

## Gray Area 3 — DTU Mock Scope, Generation & Hosting

**Sub-areas decided:** (3a) Coverage, (3b) Generation, (3c) Hosting, (3d) Chaos + contract test hook.

### (3a) Mock Coverage in Phase 3

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. GitHub API only (SAND-03 literal) | Narrow scope; matches SAND-03 text | Agent-generated code hitting arbitrary URLs silently fails | |
| B. GitHub + LLM-provider mocks | Enables adapter E2E without token burn | Doubles mock surface; bleeds into OPS-02 territory | |
| C. GitHub + generic HTTP sink | Unknown-endpoint discovery automatic | 200-echo sink gives false positives; conflicts "fail loudly" | |
| D. GitHub in P3, LLM mocks in P5, generic sink deferred | Phase scope discipline; LLM mocks land with OPS-02 consumers | Two hosting migrations if P5 adds new providers | ✓ |

### (3b) Generation Pipeline

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. Schema-driven from OpenAPI (Prism-style) | `github/rest-api-description` stable OpenAPI 3.1; mechanical drift detection | Elixir OpenAPI server-stub codegen is alpha + client-only; Prism random examples fail SDK round-trip fidelity | |
| B. Hand-written Plug modules (narrow P3 set) | Full control; behavioral realism | No automatic drift detection | |
| C. Hybrid: hand-written handlers + JSV-validated responses against pinned OpenAPI | Behavioral richness from hand-crafted + schema correctness at send-time; catches drift | Two sources of truth | ✓ |
| D. Record-and-replay (VCR/Polly/Tape-style cassettes) | Real-world accuracy | PAT leak into fixtures = SEC-01 violation; StrongDM explicitly rejected this | |

### (3c) Hosting Model

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. Sidecar in compose.yaml | Clean network topology; compatible with `internal: true`; LocalStack-proven | Separate lifecycle | ✓ |
| B. Bandit + Plug inside Kiln BEAM | Single dev cycle | Cannot reach `internal: true` bridge from host without breaking SC #2 egress tests — architecturally broken | |
| C. Separate Elixir sub-app (umbrella-like) | Strongest isolation | Violates D-97 single-app invariant | |
| D. Hybrid BEAM for tests + sidecar for runs | Test speed + prod realism | Duplicate mock code = drift | |

### (3d) Chaos + Contract Test Hook

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. Full chaos in P3 (5-6 modes + header-driven + probabilistic) | One-time chaos investment | Most modes not exercised until P5 — unexercised code | |
| B. Minimal (429 + 503 only) + scaffolded contract harness | Exactly matches SAND-03 "chaos mode scaffolded" + pitfall P6 "weekly contract-test harness scaffolded"; D-91 precedent | Test author wanting timeout chaos in P4 adds it then | ✓ |
| C. No chaos, scaffold only | Smallest surface | Misses explicit SAND-03 wording | |

**User's choice:** D, C, A, B.

---

## Gray Area 4 — Secrets, Block Reasons & BudgetGuard

**Sub-areas decided:** (4a) Secret timing, (4b) Reference shape + redaction, (4c) Block reasons scope + playbook storage, (4d) BudgetGuard scope.

### (4a) Secret Store Resolution Timing

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. Eager + fail-fast in prod, warn in dev (BootChecks invariant) | Aligns P1 boot-validation discipline; Plausible pattern | `:prod` boot fails if any provider key absent even if provider isn't used | |
| B. Lazy on-first-use | Literal SC #4 wording | Problems surface late; `persistent_term` runtime mutation = global GC | |
| C. Hybrid: eager at boot + presence map + stage-start typed block | Literal SC #4 compliance AND boot visibility AND no runtime `persistent_term` mutation | Slightly more code than A | ✓ |

### (4b) Secret Reference Shape

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. `%Kiln.Secrets.Ref{name: atom}` struct + scoped `reveal!/1` | Type-system-enforced; `Inspect` derive; grep-audit decidable for `reveal!` | Requires adapter-boundary discipline | ✓ |
| B. Plain atom `:anthropic_api_key` | Minimal ceremony | Ambiguous (atoms appear everywhere); grep-audit undecidable | |
| C. Nested atom list `[:kiln, :secrets, ...]` | Explicit about source hierarchy | Verbose; no type-system protection | |

**Six redaction layers (ALL ship in P3):** type-system boundary, `@derive {Inspect, except: [:api_key]}`, Ecto `redact: true`, `LoggerJSON.Redactor`, `Ecto.Changeset.redact_fields`, docker-inspect negative test. **Bonus 7th:** `:telemetry` emission-boundary `%Ref{}` assertion.

### (4c) Block Reasons Scope & Playbook Storage

**Scope:**

| Option | Selected |
|--------|----------|
| A. All 9 reasons + 9 playbooks in P3 | |
| B. P3-relevant subset (6), defer 3 | |
| C. All 9 atoms in enum + 5-6 authored + 3-4 stub playbooks with `owning_phase` frontmatter | ✓ (revised: 6 real + 3 stubs — `policy_violation` has a live consumer via sandbox env allowlist D-134) |

**Storage:**

| Option | Selected |
|--------|----------|
| A. Markdown + YAML frontmatter under `priv/playbooks/v1/<reason>.md` + compile-time `PlaybookRegistry` via `@external_resource` | ✓ |
| B. Inline Elixir module with `%Playbook{}` struct per function clause | |
| C. Pure YAML | |

**Rationale:** Option A mirrors D-09 `Kiln.Audit.SchemaRegistry` + D-73 `Kiln.Stages.ContractRegistry` + `Kiln.Workflows.SchemaRegistry` for the 4th time — architectural cohesion. Markdown body renders to terminal + LiveView + Slack without content rewrite. Frontmatter validated by JSV schema at `priv/playbook_schemas/v1/playbook.json`.

### (4d) BudgetGuard Scope

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| A. Per-call pre-flight only | Minimum P3 surface | Doesn't address PITFALLS P2 "spend in last 60min" global breaker; one run can eat the factory | |
| B. Per-call + global FactoryCircuitBreaker ACTIVE | Completely closes P2 in P3 | Global breaker semantics belong to Phase 5 bounded-autonomy charter | |
| C. Per-call active + global breaker SCAFFOLDED as supervised no-op | D-91 StuckDetector precedent; closes structural gap without expanding behavioral scope; zero P5 schema migration | No-op visible in supervision tree for 2 phases | ✓ |

**Token counting:** Anthropic `count_tokens` endpoint (free, rate-limited, industry-default per Propel/LangSmith/Langfuse 2025). Size-heuristic rejected as Fabro $X/hour + Gas Town retry-storm footgun.

**Budget-exceeded behavior:** strict playbook "edit workflow caps + restart run". **No `KILN_BUDGET_OVERRIDE` escape hatch** (least-surprise for solo op at 2am: "I want to be stopped").

**User's choice:** C, A, C + A, C (per research agent's coherent recommendation).

---

## Claude's Discretion

Planner and executor have flexibility on (from CONTEXT.md):

- Exact module file names within each context's directory
- `Kiln.Agents.Prompt.t()` and `Response.t()` struct internals (public API documented)
- Exact pricing numbers in `priv/pricing/v1/<provider>.exs` (planner fetches during `/gsd-research-phase 3`)
- Exact resource limit values in `priv/sandbox/limits.yaml` within policy shape (research-validated)
- Finch per-provider pool sizing within aggregate budget
- Test fixture shapes under `test/fixtures/`
- DTU handler file organization under `priv/dtu/lib/kiln_dtu/handlers/github/`
- OrphanSweeper as GenServer vs boot-time Task
- Playbook Mustache-var substitution inline function vs micro-lib
- Playbook body copy/voice (within Kiln brand-book rules)
- Test organization under `test/kiln/{agents,sandboxes,blockers,policies}/`

---

## Deferred Ideas

Captured in full in `03-CONTEXT.md <deferred>` section. Summary: LLM-provider mocks (P5), full chaos taxonomy (P5), tier-cross desktop notifications (P7), streaming PubSub topology (P7), cross-provider fallback exercising (P5), FactoryCircuitBreaker body (P5), rootless Docker + microVMs (P9 hardening), per-language images beyond Elixir (as demanded), OpenAPI-driven DTU codegen (P6+), record-replay fixtures (rejected), GraphQL mocks (as demanded), typed tool allowlist full enforcement (P4), untrusted-content markers (P4), OTel metrics/logs (P9), diagnostic snapshot (P8), BLOCK-02 unblock panel (P8), intake/cost-intel (P8), real git/gh (P6), scenario runner (P5), LiveView (P7), OBS-02 full OTel coverage (P9).

---

## Research Agent Outputs

Four parallel `gsd-advisor-researcher` agents ran concurrently (~4-5min total), each producing:
- Full option comparison tables per sub-decision
- Elixir/Phoenix idiomaticity analysis
- Cross-ecosystem lessons (LangChain, LiteLLM, OpenRouter, Vercel AI SDK, instructor_lite, LocalStack, WireMock, Prism, Toxiproxy, Dagger, StrongDM DTU, SRE Workbook, Stripe error taxonomy, LiteLLM budget enforcement, Fuse circuit breaker, Anthropic count_tokens, persistent_term patterns, Ecto redact, LoggerJSON redactor, MuonTrap, NIST 800-190, CIS Docker Benchmark)
- Coherent one-shot recommendations per gray area
- Implementation details for CONTEXT.md
- Canonical refs (merged into CONTEXT.md `<canonical_refs>`)

Full research outputs archived in agent transcripts (not inlined here to keep log readable). Synthesized design presented to user as a single coherent table; user accepted all 16 picks with "approve b/c we'll research next anyways" (acknowledging `/gsd-research-phase 3` will validate exact numbers and flesh out implementation details).
