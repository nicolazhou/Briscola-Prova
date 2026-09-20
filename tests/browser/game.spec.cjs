const { test, expect } = require('@playwright/test');

async function waitForQaStatus(page, wanted, timeout = 15000) {
  const status = await page.waitForFunction(
    (expected) => {
      const value = window.__briscolaQaStatus || '';
      return value === expected || value.startsWith('failed-') ? value : false;
    },
    wanted,
    { timeout }
  );
  const value = await status.jsonValue();
  expect(value).toBe(wanted);
}

test('persists, reloads and completes the classic game', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(String(error)));

  await page.goto('/?qa=fresh', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('canvas')).toBeVisible();
  await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 20000 });
  await waitForQaStatus(page, 'saved');

  // Give Emscripten/IndexedDB a small deterministic window after force_fs_sync.
  await page.waitForTimeout(250);

  await page.goto('/?qa=resume', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('canvas')).toBeVisible();
  await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 20000 });
  await waitForQaStatus(page, 'complete');

  const diagnostics = await page.evaluate(() => (window.BriscolaSupport && window.BriscolaSupport.getDiagnostics()) || []);
  const fatalDiagnostics = diagnostics.filter(event => event.type !== 'console.error');
  expect(pageErrors, pageErrors.join('\n')).toEqual([]);
  expect(fatalDiagnostics, JSON.stringify(fatalDiagnostics, null, 2)).toEqual([]);
});

test('four-player teams QA match completes', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(String(error)));

  await page.goto('/?qa=4p', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('canvas')).toBeVisible();
  await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 20000 });
  await waitForQaStatus(page, '4p-complete', 15000);
  expect(pageErrors, pageErrors.join('\n')).toEqual([]);
});
