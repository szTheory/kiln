import { test, loadFixtureIds } from "../fixtures/kiln";

/**
 * Accessibility scan — WCAG2A + WCAG2AA via @axe-core/playwright.
 *
 * Fails on `serious` or `critical` violations only (contrast, labels,
 * landmarks, keyboard focusability). `moderate`/`minor` are reported
 * in traces but don't fail builds — pragmatic per the brand book's
 * contrast-first posture.
 *
 * Runs across the full viewport/color-scheme matrix defined in
 * `playwright.config.ts`, so dark-mode-only contrast bugs surface
 * without needing a separate matrix here.
 */

const fixtureIds = loadFixtureIds();

const A11Y_ROUTES: { name: string; path: string }[] = [
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
  { name: "settings", path: "/settings" },
  { name: "audit", path: "/audit" },
  { name: "spec-editor", path: `/specs/${fixtureIds.spec_id}/edit` },
];

for (const route of A11Y_ROUTES) {
  test(`axe clean (serious/critical): ${route.name}`, async ({ kiln }) => {
    await kiln.goto(route.path);
    await kiln.axeScan();
  });
}
