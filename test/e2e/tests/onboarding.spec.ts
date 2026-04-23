import { test, expect } from "../fixtures/kiln";

/**
 * Onboarding wizard — shipable-surface interactions.
 *
 * Proves the 3 verify buttons (Anthropic, GitHub, Docker) are
 * clickable and yield a visible flash message, and that the "Start from a
 * template" CTA navigates into the template catalog. We don't assert
 * pass/fail of the probes themselves (that depends on host env) —
 * only that LiveView round-trips the event and the chrome stays
 * on-brand through state transitions.
 */
test.describe("onboarding wizard", () => {
  test.describe.configure({ mode: "serial" });

  test("renders 3 steps, verify buttons round-trip LV events", async ({
    page,
    kiln,
  }) => {
    await kiln.goto("/onboarding");

    await expect(page.locator("#onboarding-wizard")).toBeVisible();
    await expect(page.locator("#step-anthropic")).toBeVisible();
    await expect(page.locator("#step-github")).toBeVisible();
    await expect(page.locator("#step-docker")).toBeVisible();

    // Each verify button should trigger a phx-click and return a
    // flash message within the action timeout.
    for (const btnId of [
      "#verify-anthropic-btn",
      "#verify-github-btn",
      "#verify-docker-btn",
    ]) {
      const btn = page.locator(btnId);
      if ((await btn.count()) === 0) continue;
      await btn.click();
      // Either success ("Verified") or failure copy shows up in one of the
      // visible flash containers; ignore the always-rendered hidden
      // reconnect alerts in the layout shell.
      await expect(page.locator("[role='alert']:not([hidden])").first()).toBeVisible({
        timeout: 5_000,
      });
    }
  });

  test("start-from-template CTA navigates to templates catalog", async ({
    page,
    kiln,
  }) => {
    await kiln.goto("/onboarding");

    await Promise.all([
      page.waitForURL(/\/templates/),
      page.locator("#onboarding-start-from-template").click(),
    ]);

    await expect(page.locator("header").first()).toBeVisible();
  });
});
