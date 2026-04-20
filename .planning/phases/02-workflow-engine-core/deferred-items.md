# Phase 02 Deferred Items

Logged during plan execution — items discovered out-of-scope for the current plan.

| Plan | Category | Item | Raised by |
|------|----------|------|-----------|
| 02-01 | Test fixture shape | `test/support/fixtures/workflows/cyclic.yaml` uses single-char stage ids `a`, `b`, `c` which violate the D-58 stage id regex `^[a-z][a-z0-9_]{1,31}$` (min 2 chars). JSV rejects at the schema layer before D-62 validator 2 (topological sort) can detect the cycle. Fixture must be updated to use 2+ char IDs (e.g., `aa`, `bb`, `cc`) so the downstream workflow-loader tests that consume this fixture exercise the intended rejection path. Shipped by Plan 02-00; consumed by Plan 02-02+ (workflow loader). | 02-01 Task 1 verification (positive-validate check) |
