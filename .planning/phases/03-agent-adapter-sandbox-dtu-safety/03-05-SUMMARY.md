---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "05"
subsystem: agents
tags:
  - phase-3
  - wave-2
  - agents
  - adapter
  - anthropic
  - structured-output
  - session-supervisor
  - agent-01
completed: 2026-04-20
---

# Phase 3 Plan 05: Agent Adapters Summary

Recovered and landed the Wave 2 agent-adapter substrate from the interrupted worktree output.

## Shipped

- `Kiln.Agents.Adapter` behaviour with four callbacks: `complete/2`, `stream/2`, `count_tokens/1`, `capabilities/0`
- `%Kiln.Agents.Prompt{}` and `%Kiln.Agents.Response{}` as the provider-agnostic prompt/response envelopes
- `Kiln.Agents.SessionSupervisor` as an empty `DynamicSupervisor` placeholder for Phase 4 session ownership
- `Kiln.Agents.Adapter.Anthropic` as the live adapter
- `Kiln.Agents.Adapter.OpenAI`, `.Google`, `.Ollama` as scaffolded adapters
- `Kiln.Agents.StructuredOutput` as the provider-aware structured-output facade
- 38 targeted tests passing across adapter contracts, prompt/response structs, Anthropic, scaffolded adapters, and structured output

## Key Decisions

- Anthropic is the only live provider in Phase 3; OpenAI, Google, and Ollama compile cleanly behind the same behaviour and are exercised by contract tests.
- Structured output is routed through provider-native modes where possible, rather than a single raw-JSON retry loop.
- `Prompt` intentionally excludes `:metadata` from its derived JSON encoding so secret references and contextual metadata do not leak into generic serialization paths.
- `SessionSupervisor` is shipped now as the stable ownership boundary even though it remains empty until the Phase 4 agent tree fills it in.

## Recovery Notes

- The interrupted worktree contained complete implementation commits but no summary/closeout commit.
- Recovery validated the full targeted Phase 3 adapter suite before merge.
- The code landed via recovery merge on `main`; this summary restores the missing GSD artifact so the plan is no longer invisible to the workflow state.

## Verification

- `mix test test/kiln/agents/adapter_contract_test.exs test/kiln/agents/prompt_test.exs test/kiln/agents/response_test.exs test/kiln/agents/structured_output_test.exs test/kiln/agents/adapter/anthropic_test.exs test/kiln/agents/adapter/openai_test.exs test/kiln/agents/adapter/google_test.exs test/kiln/agents/adapter/ollama_test.exs`
- Result: `38 tests, 0 failures (4 excluded)`
