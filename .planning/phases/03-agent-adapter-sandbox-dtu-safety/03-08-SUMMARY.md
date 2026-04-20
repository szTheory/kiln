---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "08"
subsystem: sandbox-driver-runtime
tags:
  - phase-3
  - wave-4
  - sandboxes
  - docker
  - orphan-sweeper
  - sand-01
  - sand-02
completed: 2026-04-20
---

# Phase 3 Plan 08: Sandbox Driver Runtime Summary

Finished the host-side runtime pieces for the Phase 3 sandbox path: the Docker driver surface now has its companion orphan-sweep process and supervisor wiring, and the `Kiln.Sandboxes` context doc now reflects the real hardened-container contract instead of the old placeholder text.

## Shipped

- `Kiln.Sandboxes.OrphanSweeper` as a long-running GenServer that defers boot-time work, enumerates stale containers via the driver surface, force-removes them with `docker rm -f`, emits `:orphan_container_swept` audit events, and re-arms a periodic scan
- `Kiln.Sandboxes.Supervisor` with the Phase 3 child ordering contract: `OrphanSweeper` first, `Kiln.Notifications.DedupCache` second
- Rewritten `Kiln.Sandboxes` moduledoc documenting the Docker hardening contract (`kiln-sandbox`, `--cap-drop=ALL`, `--security-opt=no-new-privileges`, read-only rootfs, no Docker socket mount)
- `test/kiln/sandboxes/orphan_sweeper_test.exs` covering boot deferral, orphan sweeping, periodic re-arm behavior, supervisor child ordering, and the updated context docs

## Key Decisions

- `OrphanSweeper` resolves its injected functions from application config on each scan rather than storing function references in state. That keeps the GenServer state tiny and lets the existing tests replace behavior with `Application.put_env/3` stubs.
- Zero or negative `periodic_scan_ms` values reschedule with `send/2` instead of `Process.send_after/3`, so the tests can exercise the re-arm path deterministically without sleeps.
- The sweep audit payload records the orphan `container_id` and observed `boot_epoch_found` immediately before the forced removal. That matches the Phase 3 audit vocabulary without pulling later boot-check wiring into this plan.

## Deviations from Plan

- The plan called for the adversarial egress and secret-leak suites, but those tests are not present in the recovered Wave 4 worktree. This closeout covers the shipped Docker driver + orphan-sweeper runtime and leaves the adversarial regression slice to later Phase 3 integration work.
- `OrphanSweeper` uses the already-shipped `Kiln.Sandboxes.DockerDriver.list_orphans/1` surface rather than talking to the Docker API client directly. The driver remains the single container-enumeration seam.

## Verification

- `mix compile --warnings-as-errors`
- `mix test test/kiln/sandboxes/docker_driver_test.exs test/kiln/sandboxes/orphan_sweeper_test.exs --max-failures=1`

## Remaining Follow-On

- `Kiln.Sandboxes.Supervisor` exists but is not wired into the application tree yet. Plan 03-11 owns that boot integration.
- The adversarial egress and secret-leak suites remain absent from the repo and should be treated as still pending if the Phase 3 acceptance bar depends on them.
