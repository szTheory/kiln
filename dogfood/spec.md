# Dogfood spec — `Kiln.Version` helper

Smallest shippable change for the Phase 9 dogfood path: add a tiny
read-only module that exposes the application version string.

## Goal

- Add `Kiln.Version.string/0` returning the release vsn (from
  `Application.spec(:kiln, :vsn)` at runtime — **not** prompt bodies or
  workflow YAML).

## Files touched (allowlist only)

- `lib/kiln/version.ex`
- `test/kiln/version_test.exs`
- Optional one-line pointer in `README.md` (no marketing copy).

## Verification

- **`mix check`** must pass on the PR branch before auto-merge.

## Out of scope

- Changes under `.github/workflows/` (blocked by dogfood allowlist
  unless explicitly expanded in a future spec revision).

## Acceptance

- CI green: existing **`mix check`** job on `main` / PR head.
- Module name **`Kiln.Version`** appears in this spec so template-load
  tests can grep for it (D-901 / D-905).
