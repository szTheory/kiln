---
title: Workflows
description: Authoring YAML workflows, validating with JSV, and the planning loop Kiln expects.
---

## Specs and YAML

Kiln workflows live as versioned YAML. Validate locally against the JSON Schema Draft 2020-12 bundle the project ships.

## Practices

- Keep stages small and idempotent.
- Record external operations with intent rows before side effects.
- Prefer explicit model names over implicit defaults.

This stub links forward to architecture for the four-layer mental model.
