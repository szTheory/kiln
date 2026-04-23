import { test as base, expect, type Page, type ConsoleMessage } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

/**
 * Shared Kiln e2e fixture.
 *
 * - Loads canonical fixture IDs written by `priv/repo/seeds_e2e.exs`
 *   (`test/e2e/.fixture-ids.json`) so specs can reference `/runs/<id>`
 *   and `/specs/<id>/edit` by literal paths without re-discovering IDs
 *   per test.
 * - Exposes a `kiln` fixture with a `goto(path, opts?)` helper that
 *   waits for LiveView `phx-connected`, a `consoleErrors` sink that
 *   fails a spec on unexpected JS/LV errors, and an `axeScan(page)`
 *   helper that runs WCAG2A/AA and fails on serious/critical
 *   violations (matches the brand book's contrast-first UX posture).
 * - Accepts a `KILN_E2E_STRICT_CONSOLE=0` env escape hatch for
 *   narrow-iteration local runs where upstream console noise is OK.
 */

export type FixtureIds = {
  run_a_id: string;
  run_b_id: string;
  workflow_id: string;
  spec_id: string;
  template_id: string;
};

const FIXTURES_PATH = join(__dirname, "..", ".fixture-ids.json");

export function loadFixtureIds(): FixtureIds {
  if (!existsSync(FIXTURES_PATH)) {
    throw new Error(
      `Missing ${FIXTURES_PATH}. Run 'bash script/e2e_boot.sh' or 'mix kiln.e2e' ` +
        "to seed fixtures before Playwright."
    );
  }
  return JSON.parse(readFileSync(FIXTURES_PATH, "utf8")) as FixtureIds;
}

type KilnFixture = {
  goto: (path: string, opts?: { waitForConnected?: boolean }) => Promise<void>;
  consoleErrors: string[];
  axeScan: (options?: { include?: string; exclude?: string[] }) => Promise<void>;
};

const STRICT_CONSOLE = process.env.KILN_E2E_STRICT_CONSOLE !== "0";

// Console messages we explicitly allow — e.g., LiveView dev-mode
// notices that don't indicate a real problem.
const CONSOLE_ALLOWLIST: RegExp[] = [
  /\[phoenix\] connected/i,
  /download the React DevTools/i,
  // Favicon 404s on some routes — not a reskin regression signal.
  /Failed to load resource:.*favicon/i,
  // Navigation races can close the LV websocket before the initial handshake.
  /WebSocket connection to 'ws:\/\/localhost:4000\/live\/websocket.*closed before the connection is established/i,
  // WebKit can report LiveView longpoll fallbacks as page errors during route changes.
  /\/live\/longpoll.*due to access control checks/i,
];

function isNoise(text: string): boolean {
  return CONSOLE_ALLOWLIST.some((rx) => rx.test(text));
}

export const test = base.extend<{ kiln: KilnFixture }>({
  kiln: async ({ page }, use) => {
    const consoleErrors: string[] = [];

    const onConsole = (msg: ConsoleMessage) => {
      if (msg.type() !== "error" && msg.type() !== "warning") return;
      const text = msg.text();
      if (isNoise(text)) return;
      consoleErrors.push(`[${msg.type()}] ${text}`);
    };
    const onPageError = (err: Error) => {
      if (isNoise(err.message)) return;
      consoleErrors.push(`[pageerror] ${err.message}`);
    };
    page.on("console", onConsole);
    page.on("pageerror", onPageError);

    const fixture: KilnFixture = {
      consoleErrors,

      async goto(path, opts = {}) {
        const { waitForConnected = true } = opts;
        const response = await page.goto(path);
        expect(
          response,
          `no response for ${path} (server down?)`
        ).not.toBeNull();
        expect(response!.status(), `unexpected status for ${path}`).toBeLessThan(400);

        if (waitForConnected) {
          // The initial HTTP render can arrive before the LiveSocket is
          // actually connected. Wait for the root LiveView container to
          // reach the connected class so clicks and submits don't race the
          // websocket mount.
          await page.waitForSelector("[data-phx-main].phx-connected", {
            timeout: 20_000,
          });
        }
      },

      async axeScan(options) {
        let builder = new AxeBuilder({ page }).withTags([
          "wcag2a",
          "wcag2aa",
        ]);
        if (options?.include) builder = builder.include(options.include);
        if (options?.exclude) {
          for (const sel of options.exclude) builder = builder.exclude(sel);
        }
        const results = await builder.analyze();
        const blocking = results.violations.filter(
          (v) => v.impact === "serious" || v.impact === "critical"
        );
        expect(
          blocking,
          `axe-core found ${blocking.length} serious/critical a11y violations:\n` +
            blocking
              .map((v) => `  - ${v.id} (${v.impact}): ${v.help} — ${v.helpUrl}`)
              .join("\n")
        ).toEqual([]);
      },
    };

    await use(fixture);

    page.off("console", onConsole);
    page.off("pageerror", onPageError);

    if (STRICT_CONSOLE && consoleErrors.length > 0) {
      throw new Error(
        `Unexpected console errors during test:\n${consoleErrors.join("\n")}`
      );
    }
  },
});

export { expect } from "@playwright/test";
export type { Page };
