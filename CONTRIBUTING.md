# Contributing to Kiln

## Application (Elixir / Phoenix)

The default developer loop is Elixir-native:

```bash
mix setup
mix check
```

`mix check` and `mix precommit` do **not** install or invoke Node for the Phoenix app.

## Documentation site (Astro)

Operator docs and the public landing page live in **`site/`** (Astro + Starlight). CI builds and checks them on changes under `site/` via **`.github/workflows/docs.yml`** — that workflow is the **source of truth** on `main`.

Prerequisites when editing the site locally:

- **Node.js 22** and **pnpm 9** (see `site/package.json` `packageManager`).

Commands (mirror `site/README.md`):

```bash
cd site
pnpm install
pnpm exec astro build
pnpm exec astro preview
pnpm run verify:mermaid
```

Optional one-shot parity with CI (requires `htmltest`, `lychee`, and `typos` on your `PATH` after a successful build):

```bash
DOCS=1 mix docs.verify
```

Without `DOCS=1`, `mix docs.verify` prints a skip message and exits **0** so default `mix check` stays unchanged.

## Published site

After GitHub Pages is enabled for the repository, the static site is served at **`https://szTheory.github.io/kiln/`** (with `base` `/kiln`).
