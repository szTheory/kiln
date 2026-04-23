import { test, expect } from "../fixtures/kiln";

/**
 * Inbox — create-draft happy path.
 *
 * Fills the freeform "New draft" form and asserts the draft appears
 * in the `#inbox-drafts` stream container with a Promote button. This
 * exercises LiveView form submission + stream append end-to-end.
 */
test("inbox: create freeform draft appears in drafts stream", async ({
  page,
  kiln,
}) => {
  await kiln.goto("/inbox");

  const title = `e2e draft ${Date.now()}`;
  const drafts = page.locator("#inbox-drafts");

  await page.locator("#inbox-freeform-form input[name='draft[title]']").fill(title);
  await page
    .locator("#inbox-freeform-form textarea[name='draft[body]']")
    .fill("Draft body created by Playwright.");

  await page.locator("#inbox-freeform-form button[type='submit']").click();

  await expect(page.locator("#flash-info")).toContainText("Draft created", {
    timeout: 10_000,
  });
  await expect(drafts).toContainText(title, { timeout: 10_000 });

  await expect(drafts.locator("button[phx-click='promote']").first()).toBeVisible();
});
