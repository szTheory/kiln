import { test, expect, loadFixtureIds } from "../fixtures/kiln";

/**
 * All 14 LiveView routes from `KilnWeb.Router`'s `live_session :default`.
 *
 * Each is exercised with:
 *   - Mount + `data-phx-main` present + status < 400.
 *   - Header landmark present (operator chrome).
 *   - No retired Phase-reskin tokens in the live DOM.
 *   - Strict console error/warning sink (see `fixtures/kiln.ts`).
 *
 * The matrix expands via the 4 projects in `playwright.config.ts`
 * (mobile-safari + desktop-chromium, each in light + dark), so in
 * practice this file produces 14 x 4 = 56 runs per `npx playwright test`.
 */

const RETIRED_TOKENS = [
  "text-bone",
  "text-ember",
  "border-ash",
  "border-clay",
  "border-ember",
  "bg-char",
  "bg-iron",
  "text-[var(--color-smoke)]",
  "text-[var(--color-clay)]",
  "kiln-btn",
] as const;

const fixtureIds = loadFixtureIds();

const ROUTES: { name: string; path: string }[] = [
  { name: "onboarding", path: "/onboarding" },
  { name: "run-board", path: "/" },
  { name: "templates-index", path: "/templates" },
  { name: "templates-show", path: `/templates/${fixtureIds.template_id}` },
  { name: "inbox", path: "/inbox" },
  {
    name: "run-compare",
    path: `/runs/compare?baseline=${fixtureIds.run_a_id}&candidate=${fixtureIds.run_b_id}`,
  },
  { name: "run-replay", path: `/runs/${fixtureIds.run_a_id}/replay` },
  { name: "run-detail", path: `/runs/${fixtureIds.run_a_id}` },
  { name: "workflows-index", path: "/workflows" },
  { name: "workflows-show", path: `/workflows/${fixtureIds.workflow_id}` },
  { name: "costs", path: "/costs" },
  { name: "providers", path: "/providers" },
  { name: "audit", path: "/audit" },
  { name: "spec-editor", path: `/specs/${fixtureIds.spec_id}/edit` },
];

for (const route of ROUTES) {
  test(`route renders on-brand: ${route.name} (${route.path})`, async ({
    page,
    kiln,
  }) => {
    await kiln.goto(route.path);

    await expect(page.locator("header").first()).toBeVisible();

    const bodyHTML = await page.evaluate(() => document.body.innerHTML);
    for (const token of RETIRED_TOKENS) {
      expect(
        bodyHTML,
        `${route.path}: rendered DOM contains retired token \`${token}\``
      ).not.toContain(token);
    }
  });
}
