import { test, expect } from "../fixtures/kiln";

/**
 * Theme toggle round-trip.
 *
 * Guards the `phx:set-theme` contract wired in `root.html.heex` +
 * `layouts.ex theme_toggle/1`:
 *   1. Click dark → `<html data-theme="dark">` and
 *      `localStorage.phx:theme === "dark"`.
 *   2. Click light → `<html data-theme="light">` and
 *      `localStorage.phx:theme === "light"`.
 *   3. Click system → `<html>` has no `data-theme`,
 *      `localStorage.phx:theme` removed.
 *   4. Reload after step 1 — dark persists across page load (the
 *      inline `<script>` in root.html.heex reapplies before paint).
 */
test.describe("theme toggle", () => {
  test("light → dark → system round-trip persists in localStorage", async ({
    page,
    kiln,
  }) => {
    await kiln.goto("/onboarding");

    const html = page.locator("html");

    // Dark
    await page.locator('[data-phx-theme="dark"]').click();
    await expect(html).toHaveAttribute("data-theme", "dark");
    expect(
      await page.evaluate(() => window.localStorage.getItem("phx:theme"))
    ).toBe("dark");

    // Light
    await page.locator('[data-phx-theme="light"]').click();
    await expect(html).toHaveAttribute("data-theme", "light");
    expect(
      await page.evaluate(() => window.localStorage.getItem("phx:theme"))
    ).toBe("light");

    // System — removes the attribute and the localStorage key
    await page.locator('[data-phx-theme="system"]').click();
    await expect(html).not.toHaveAttribute("data-theme", "light");
    await expect(html).not.toHaveAttribute("data-theme", "dark");
    expect(
      await page.evaluate(() => window.localStorage.getItem("phx:theme"))
    ).toBeNull();
  });

  test("dark selection persists across hard reload", async ({ page, kiln }) => {
    await kiln.goto("/onboarding");
    await page.locator('[data-phx-theme="dark"]').click();
    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");

    await page.reload();

    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
    expect(
      await page.evaluate(() => window.localStorage.getItem("phx:theme"))
    ).toBe("dark");
  });
});
