---
phase: 09-dogfood-release-v0-1-0
plan: "02"
subsystem: infra
tags: [opentelemetry, observability, compose]

key-files:
  created:
    - lib/kiln/telemetry/otel.ex
    - lib/kiln/telemetry/spans.ex
    - deploy/otel-collector.yaml
    - test/kiln/telemetry/otel_smoke_test.exs
  modified:
    - mix.exs
    - mix.lock
    - config/runtime.exs
    - lib/kiln/application.ex
    - lib/kiln/runs/transitions.ex
    - lib/kiln/sandboxes/docker_driver.ex
    - lib/kiln/agents/adapter/anthropic.ex
    - compose.yaml
---

# Plan 09-02 Summary

- Hex: `opentelemetry_phoenix`, `opentelemetry_bandit`, `opentelemetry_ecto`, `opentelemetry_oban`, `opentelemetry_process_propagator`.
- `Kiln.Telemetry.Otel.setup/0` attaches instrumenters after `BootChecks.run!/0`.
- `Kiln.Telemetry.Spans` exposes `kiln.run.stage`, `kiln.agent.call`, `kiln.docker.op`, `kiln.llm.request` — wired at transitions, Anthropic `complete/2`, Docker `kill/1`.
- `config/runtime.exs`: OTLP exporter when `OTEL_EXPORTER_OTLP_ENDPOINT` set; `:none` in test.
- Compose: `otel-collector` + `jaeger` with OTLP gRPC on **4317** per plan.

## Self-Check: PASSED

- `mix test test/kiln/telemetry/otel_smoke_test.exs`
- `docker compose config`
