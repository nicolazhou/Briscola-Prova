const { test, expect } = require('@playwright/test');

async function waitForQaStatus(page, wanted, timeout = 100000) {
  await page.waitForFunction(
    (expected) => window.__briscolaQaStatus === expected,
    wanted,
    { timeout }
  );
}

test('loads Godot, persists a game, reloads and completes it', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(String(error)));

  await page.goto('/?qa=fresh', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('canvas')).toBeVisible();
  await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 30000 });
  await waitForQaStatus(page, 'saved');

  // Reload the same origin/context: this exercises Godot's persistent Web
  // filesystem rather than an in-memory test double.
  await page.goto('/?qa=resume', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('canvas')).toBeVisible();
  await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 30000 });
  await waitForQaStatus(page, 'complete');

  const diagnostics = await page.evaluate(() => (window.BriscolaSupport && window.BriscolaSupport.getDiagnostics()) || []);
  const fatalDiagnostics = diagnostics.filter(event => event.type !== 'console.error');
  expect(pageErrors, pageErrors.join('\n')).toEqual([]);
  expect(fatalDiagnostics, JSON.stringify(fatalDiagnostics, null, 2)).toEqual([]);
});


test('four-player teams beta boots and completes a QA match', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(String(error)));
  await page.goto('/?qa=4p', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('canvas')).toBeVisible();
  await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 30000 });
  await page.waitForFunction(() => window.__briscolaQaStatus === '4p-complete', null, { timeout: 60000 });
  expect(pageErrors, pageErrors.join('\n')).toEqual([]);
});
