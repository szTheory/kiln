import { defineConfig, devices } from "@playwright/test";

/**
 * Kiln operator LiveView e2e configuration.
 *
 * Two viewport projects (mobile + desktop) x two color schemes (light +
 * dark) = four test runs per spec — matches the Phase-reskin
 * verification matrix. WebKit is included as the default mobile engine
 * (Mobile Safari emulation) and Chromium as the desktop engine; Firefox
 * is skipped to keep CI minutes reasonable and because the reskin
 * relies on no Firefox-specific behavior.
 *
 * The server is expected to be running on http://localhost:4000 before
 * `playwright test` — boot via `bash script/e2e_boot.sh` or `mix kiln.e2e`.
 */

const BASE_URL = process.env.KILN_E2E_BASE_URL ?? "http://localhost:4000";

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: process.env.CI
    ? [["html", { open: "never" }], ["list"], ["github"]]
    : [["html", { open: "on-failure" }], ["list"]],

  timeout: 30_000,
  expect: { timeout: 10_000 },

  use: {
    baseURL: BASE_URL,
    trace: "retain-on-failure",
    video: "retain-on-failure",
    screenshot: "only-on-failure",
    actionTimeout: 10_000,
    navigationTimeout: 20_000,
  },

  projects: [
    {
      name: "desktop-chromium-light",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1440, height: 900 },
        colorScheme: "light",
      },
    },
    {
      name: "desktop-chromium-dark",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1440, height: 900 },
        colorScheme: "dark",
      },
    },
    {
      name: "mobile-safari-light",
      use: {
        ...devices["iPhone 13"],
        colorScheme: "light",
      },
    },
    {
      name: "mobile-safari-dark",
      use: {
        ...devices["iPhone 13"],
        colorScheme: "dark",
      },
    },
  ],
});
