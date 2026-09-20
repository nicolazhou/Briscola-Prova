const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/browser',
  timeout: 60000,
  expect: { timeout: 10000 },
  fullyParallel: true,
  workers: process.env.CI ? 3 : undefined,
  retries: 0,
  reporter: process.env.CI ? [['line'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: process.env.PLAYWRIGHT_TEST_BASE_URL || 'http://127.0.0.1:8765',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'off',
  },
  projects: [
    {
      name: 'chromium-desktop',
      testMatch: ['**/*.spec.cjs'],
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox-desktop',
      testMatch: ['**/smoke.spec.cjs'],
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit-desktop',
      testMatch: ['**/smoke.spec.cjs'],
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'iphone-webkit',
      testMatch: ['**/smoke.spec.cjs'],
      use: { ...devices['iPhone 13'] },
    },
    {
      name: 'android-chromium',
      testMatch: ['**/smoke.spec.cjs'],
      use: { ...devices['Pixel 7'] },
    },
  ],
});
