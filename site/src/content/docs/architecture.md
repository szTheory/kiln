---
title: Architecture
description: Four-layer system map — Intent, Workflow, Execution, and Control contexts.
---

Kiln is a single Phoenix application with strict bounded contexts. The supervision tree, run state machine, and audit ledger are described in `.planning/research/ARCHITECTURE.md` in the repository.

## Flow (high level)

```mermaid
flowchart LR
  Intent[Intent] --> Workflow[Workflow]
  Workflow --> Execution[Execution]
  Execution --> Control[Control]
```

Diagrams are validated in CI with `pnpm run verify:mermaid` so invalid Mermaid syntax fails before merge.
