# Hello Kiln

Minimal operator-facing spec for first successful **promoted spec → run** practice.

## Goal

Ship a tiny, verifiable change in the Kiln tree (for example a read-only helper or
one focused test) using the **`elixir_phoenix_feature`** workflow.

## Files touched (illustrative)

- One small module under `lib/kiln/` and matching `test/` coverage.

## Verification

- `mix test` for the touched test file(s).
- **`mix check`** green before merge.

## Out of scope

- Production secrets, billing changes, or workflow edits.
