# Kiln documentation site (Astro + Starlight)

Static operator docs and landing page. Published to GitHub Pages from `main` (see `.github/workflows/docs.yml`).

## Commands

```bash
cd site
pnpm install
pnpm exec astro build
pnpm exec astro preview
```

## Paths

- Built output: `site/dist/` (Astro default).
- Site `base` is `/kiln` for `https://szTheory.github.io/kiln/`.
- Starlight docs routes are under `/docs/…` via nested `src/content/docs/docs/` (see [Starlight manual — subpath](https://starlight.astro.build/manual-setup/#use-starlight-at-a-subpath)).

## Mermaid

Diagrams use fenced ` ```mermaid ` blocks. **Invalid syntax must not ship:**

- **CI / pre-merge:** run `pnpm run verify:mermaid` (`scripts/check-mermaid.mjs` — syntax parse via pinned `mermaid`; failures exit non-zero without headless Chrome).
- **`astro build`** also exercises Starlight’s MD pipeline for pages; keep diagrams small and test locally.

## Quality gates (authoritative on `main`)

Path-filtered GitHub Actions runs `astro build`, `htmltest` (via `scripts/htmltest-ci.sh` — Astro uses absolute `/kiln/…` URLs), `lychee`, and `typos`. Optional local parity: `DOCS=1 mix docs.verify` from the repository root when `htmltest`, `lychee`, and `typos` are on `PATH`.
