import { test, expect, loadFixtureIds } from "../fixtures/kiln";

/**
 * Run compare — swap baseline/candidate interaction.
 *
 * Hits `/runs/compare` with both query params set, asserts the
 * baseline and candidate `data-*` attributes hydrate from the
 * query, then clicks `#run-compare-swap` and asserts the attributes
 * flip.
 */
test("run-compare: swap flips baseline and candidate data attrs", async ({
  page,
  kiln,
}) => {
  const ids = loadFixtureIds();
  const qs = new URLSearchParams({
    baseline: ids.run_a_id,
    candidate: ids.run_b_id,
  }).toString();

  await kiln.goto(`/runs/compare?${qs}`);

  const compare = page.locator("#run-compare");
  await expect(compare).toHaveAttribute("data-baseline-id", ids.run_a_id);
  await expect(compare).toHaveAttribute("data-candidate-id", ids.run_b_id);

  await page.locator("#run-compare-swap").click();

  await expect(compare).toHaveAttribute("data-baseline-id", ids.run_b_id);
  await expect(compare).toHaveAttribute("data-candidate-id", ids.run_a_id);
});
