import { test, expect } from "../fixtures/kiln";

/**
 * Onboarding + first-use journey.
 *
 * Proves the first-use flow is coherent across:
 *   1. scenario selection,
 *   2. shared shell selector hot-swap,
 *   3. template navigation with scenario context preserved,
 *   4. the live readiness checklist remaining interactive.
 */
test.describe("onboarding wizard", () => {
  test.describe.configure({ mode: "serial" });

  test("scenario selection and shell selector hot-swap the guided journey", async ({
    page,
    kiln,
  }) => {
    await kiln.goto("/onboarding");

    await expect(page.locator("#onboarding-wizard")).toBeVisible();
    await expect(page.locator("#operator-scenario-select")).toBeVisible();

    await page.locator("#scenario-card-gameboy-first-project").click();
    await expect(page).toHaveURL(/scenario=gameboy-first-project/);
    await expect(page.locator("#onboarding-scenario-detail")).toContainText(
      "Game Boy first project"
    );

    await page.locator("#operator-scenario-select").selectOption("operator-triage-readiness");
    await expect(page.locator("#onboarding-scenario-detail")).toContainText(
      "Operator readiness triage"
    );

    await Promise.all([
      page.waitForURL(/\/templates\?from=onboarding&scenario=operator-triage-readiness/),
      page.locator("#onboarding-start-from-template").click(),
    ]);

    await expect(page.locator("#templates-scenario-banner")).toContainText(
      "Operator readiness triage"
    );
    await expect(page.locator("#operator-scenario-select")).toHaveValue(
      "operator-triage-readiness"
    );
  });

  test("attach existing repo stays explicit and lands on /attach without mutating scenario state", async ({
    page,
    kiln,
  }) => {
    await kiln.goto("/onboarding");

    await page.locator("#scenario-card-operator-triage-readiness").click();
    await expect(page).toHaveURL(/scenario=operator-triage-readiness/);
    await expect(page.locator("#onboarding-attach-existing-repo")).toBeVisible();
    await expect(page.locator("#onboarding-attach-path-note")).toContainText(
      "local path, an existing clone, or a GitHub URL"
    );
    await expect(page.locator("#operator-scenario-select")).toHaveValue(
      "operator-triage-readiness"
    );
    await expect(page.locator("#onboarding-attach-existing-repo")).toHaveAttribute(
      "href",
      "/attach"
    );

    await Promise.all([
      page.waitForURL("**/attach"),
      page.locator("#onboarding-attach-existing-repo").click(),
    ]);

    await expect(page.locator("#attach-entry-root")).toBeVisible();
    await expect(page.locator("#attach-entry-hero")).toContainText(
      "Attach existing repo"
    );
    expect(page.url()).not.toContain("scenario=");
  });

  test("live readiness checks stay interactive", async ({
    page,
    kiln,
  }) => {
    await kiln.goto("/onboarding");

    for (const btnId of [
      "#verify-anthropic-btn",
      "#verify-github-btn",
      "#verify-docker-btn",
    ]) {
      const btn = page.locator(btnId);
      await expect(btn).toBeVisible();
      await btn.click();
      await expect(page.locator("[role='alert']:not([hidden])").first()).toBeVisible({
        timeout: 5_000,
      });
    }
  });
});
