# Phase 11: Game Boy emulator dogfood vertical slice - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

First **external** git repository progressed by Kiln under **DOGFOOD-01**: spec + workflow + bounded caps + deterministic acceptance (**UAT-01**), **open test ROMs only**. The workspace is a **Game Boy emulator vertical slice** intended as a **reusable benchmark template** (one of several future templates). Kiln itself stays **Elixir / Phoenix / LiveView**; the external repo is **not** a replacement for Kiln’s stack.

**Out of scope:** Full commercial GB compatibility, audio perfection, retail ROMs, a second “product” Phoenix app inside dogfood **unless** we explicitly add an integration-testing goal later.

</domain>

<decisions>
## Implementation Decisions

### Stack clarity — Kiln vs dogfood (D-1100 — G0)

- **D-1100a — No wrong-direction pivot:** **Kiln’s operator UI and host app remain Phoenix LiveView.** Phase 11 does **not** move Kiln to Rust. **Rust** (or another non-BEAM stack) applies only to the **external benchmark repository** the factory edits in the sandbox—chosen for deterministic CPU/test harness and `cargo test` as oracle, per **GB-SPIKE.md**.
- **D-1100b — Why Rust in the external repo:** Emulation cores, lockfile discipline, and headless test ROMs fit a systems language + one-command CI. This is **idiomatic separation**: orchestration (Phoenix) vs **artifact workspace** (Rust library + tests + optional web shell).

### Observable success — “I see it” + play ROM (D-1101 — G1)

- **D-1101a — Oracle vs delight:** **Canonical acceptance** stays **native, headless, deterministic**: structured assertions (registers/memory/serial hooks/framebuffer hash), bounded frames/instructions—not wall-clock racing. Commands such as `cargo test …` / a thin `runner` CLI are the **scenario oracle** aligned with **UAT-01**.
- **D-1101b — Operator-visible output:** “See the output” is satisfied by **artifacts**, not only stdout: e.g. `report.json`, optional **PNG** / frame traces, and a **playable path** for humans (permissive test ROM or tiny homebrew).
- **D-1101c — Play ROM:** Prefer **optional** **`web/`** (static HTML + small JS) driving **Rust → WASM** built from the **same core** as tests—**not** a separate JS emulator (single source of truth). **Native SDL** may exist as **dev-only** convenience; it is **not** the default CI/oracle story.
- **D-1101d — Kiln LiveView:** Surface **links to run artifacts** (reports, `play/` bundle when built) so the operator’s “dark factory” view stays coherent—**principle of least surprise**: Kiln shows what shipped; the ROM plays in the **artifact** the run produced.
- **D-1101e — Shift-left:** At least **one** micro-scenario touching a **committed, permissively licensed** test ROM on every PR-equivalent path; heavier suites may be tiered, but never **zero** ROM execution in CI/Kiln loops.
- **D-1101f — Benchmark template narrative:** Standardize **one-command** entrypoints (`cargo test --workspace` or scoped `-p`/`-test`), pinned toolchain + **Cargo.lock**, `fixtures/` or `roms/` layout, and documented outputs so this repo can be cloned as a **template** alongside future Kiln benchmarks.

### Second Phoenix in dogfood (D-1102 — G2)

- **D-1102 — Default is “no”:** Do **not** scaffold a **second Phoenix LiveView app** inside the external dogfood repo for Phase 11. It couples OTP release concerns to an emulation benchmark, surprises operators (“I thought Kiln was the Phoenix app”), and dilutes template reuse. **Exception:** only if a later explicit requirement tests **Kiln ↔ Phoenix integration** across repos—not for “pixels on screen” alone.

### Workflow YAML (D-1103 — G3)

- **D-1103a — New workflow file:** Add a dedicated workflow (working name **`rust_gb_dogfood_v1`** — planner may adjust `id`) with the **same DAG and `kind` vocabulary** as `elixir_phoenix_feature` (plan → code → test → verify → merge): `kind` tracks **run FSM lanes**, not host language.
- **D-1103b — Honest metadata:** New `id`, `metadata.description`, and **`tags`** (e.g. `rust`, `dogfood`, `gb`). **Do not** keep **`model_profile: phoenix_saas_feature`** for this run unless it is deliberately chosen for economics; prefer a **neutral / lower-cost** preset until a Rust-tuned profile exists—**model_profile** is **cost/risk semantics**, not “repo language.”
- **D-1103c — No fake stage duplication:** Do **not** duplicate stages to mean “Rust vs Elixir”; the schema’s **`sandbox`** field is `none | readonly | readwrite` only—toolchain/image belongs in **sandbox policy + spec prose + oracle commands**, not parallel `coding` rows.
- **D-1103d — Product honesty (scenarios):** Phase 11 UAT calls for **Given/When/Then → shell commands** in the **external** clone. If Kiln’s **scenario IR** today only compiles to **in-repo ExUnit**, **implementation work** must bridge external `cargo test` (or document an interim manual oracle path)—**do not** pretend YAML alone satisfies BDD without that bridge. Track in **11-01** plan / execution notes.

### Sandbox, network, Rust deps (D-1104 — G4)

- **D-1104a — Default posture:** Sandbox stays **internal / no general egress** per **SAND-02** clarity—**do not** default to “allowlist crates.io” inside the stage (ACL sprawl, git deps, sparse index, build.rs surprises).
- **D-1104b — Two-phase materialization:** **Host-trusted prefetch** (`cargo fetch`, **`cargo vendor`**, or populate `CARGO_HOME`) with **timeouts, size caps, structured logs**, and **typed failures** (network, disk, lockfile)—then sandbox runs **`cargo test --locked`**, **`--offline`** when vendor/cache is present in the mounted workspace.
- **D-1104c — Pinning:** **`rust-toolchain.toml`** (or pinned image tag) + committed **Cargo.lock** for the slice.
- **D-1104d — DTU mock registry:** **Defer** full DTU “mini crates.io” unless the slice’s goal is explicitly **testing DTU registry behavior**—high product cost for little dogfood signal.
- **D-1104e — Caps:** Tune **`max_stage_duration_seconds` / `max_elapsed_seconds`** for worst-case **first compile**; timeouts must read as **budget/orch outcomes**, not silent “Kiln stuck” (**ORCH-06**).

### Single-command parity (D-1105 — G5)

- **D-1105:** The **exact** verifier string used in Kiln’s spec must match **one** canonical command in the external repo’s **CI** (and optional `Makefile` / `xtask`) so “green in Kiln = green locally = green in Actions.”

### Claude's Discretion

- Exact workflow `id` string and `metadata.tags` ordering.
- Whether WASM `play/` is always built or only on **verify** / manual flag.
- Small SDL dev binary naming and whether it ships in template or stays `README` only.
- Initial numeric caps (iterate after first real run timing).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 11 artifacts

- `.planning/ROADMAP.md` — Phase 11 goal, **DOGFOOD-01**, **UAT-01**, **UAT-02**.
- `.planning/PROJECT.md` — **DOGFOOD-01** bullet and v0.2.0 positioning.
- `.planning/REQUIREMENTS.md` — **UAT-01**, **UAT-02** (oracle + human intervention bounds); note REQUIREMENTS sync disclaimer until Phase 13.
- `.planning/phases/11-gameboy-dogfood-vertical-slice/11-01-PLAN.md` — Tasks, falsifiable UAT, out of scope.
- `.planning/phases/11-gameboy-dogfood-vertical-slice/GB-SPIKE.md` — Spike rationale, legal ROM policy, open questions resolved here.

### Kiln workflow + schema

- `priv/workflows/elixir_phoenix_feature.yaml` — Template DAG to mirror with honest metadata.
- `priv/workflow_schemas/v1/workflow.json` — Valid stage fields (`sandbox`, kinds, caps shape).

### Prior milestone locks (do not contradict without explicit revisit)

- `.planning/phases/10-local-operator-readiness/10-CONTEXT.md` — Layered proof, README / `first_run.sh` / onboarding split.
- `.planning/phases/09-dogfood-release-v0-1-0/09-CONTEXT.md` — Dogfood merge discipline, artifacts, external ops idempotency (**this repo’s** v0.1.0 dogfood); Phase 11 is **external** workspace but inherits **safety / audit** habits.

### Sandboxes / safety (implementation)

- `lib/kiln/sandboxes/docker_driver.ex` — `ContainerSpec` assembly; no Docker socket in sandbox containers.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`priv/workflows/elixir_phoenix_feature.yaml`** — Only shipped workflow YAML today; use as structural template for a new **`rust_*`** workflow file.
- **`Kiln.Sandboxes` / `docker_driver.ex`** — Stage execution via host `docker` CLI + `ContainerSpec`; toolchain/image policy must align with whatever image runs `cargo`.

### Established patterns

- **Run FSM** — `planning | coding | testing | verifying | merge` kinds are lifecycle lanes; language belongs in spec + sandbox, not in `kind` renames.

### Integration points

- **Model registry / profiles** — Pick a profile appropriate to **token risk** for an external benchmark; avoid misleading **Phoenix** naming on a Rust repo.
- **Scenario / verifier path** — Confirm how (or whether) Kiln maps BDD steps to **shell in external workspace** vs generated **ExUnit** only; close any gap during Phase 11 execution.

</code_context>

<specifics>
## Specific Ideas

- Operator wants **shift-left** ROM coverage and a **human-playable** ROM path (test/homebrew only), ideally opening what the run **built**—benchmark should feel like a **realistic Kiln output**, not only log lines.
- Treat this repo as the **first** of several **benchmark templates** for Kiln—favor **clear layout**, **pinned deps**, and **artifact outputs** other templates can copy.

</specifics>

<deferred>
## Deferred Ideas

- **Full DTU mock of crates.io** — only if we explicitly scope registry fidelity work.
- **Second Phoenix app inside dogfood** — only for a future phase that tests cross-repo LiveView/integration contracts.
- **Native SDL as primary demo artifact** — dev convenience only; not the canonical operator story.

### Reviewed Todos (not folded)

- None (`todo.match-phase` returned zero for phase 11).

</deferred>

---

*Phase: 11-gameboy-dogfood-vertical-slice*
*Context gathered: 2026-04-22*
