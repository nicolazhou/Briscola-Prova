const { test, expect } = require('@playwright/test');

test('PWA manifest, service worker and offline boot work', async ({ page, context }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium-desktop', 'One deterministic PWA offline check is enough in CI');

  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 30000 });

  const manifestHref = await page.locator('link[rel="manifest"]').getAttribute('href');
  expect(manifestHref).toBe('manifest.webmanifest');

  const response = await page.request.get('/manifest.webmanifest');
  expect(response.ok()).toBeTruthy();
  const manifest = await response.json();
  expect(manifest.name).toBe('Briscola Napoletana');
  expect(manifest.display).toBe('standalone');
  expect(manifest.icons.some(icon => icon.sizes === '192x192')).toBeTruthy();
  expect(manifest.icons.some(icon => icon.sizes === '512x512')).toBeTruthy();

  await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.ready;
    await registration.update();
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => navigator.serviceWorker.controller !== null, null, { timeout: 15000 });

  await context.setOffline(true);
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('canvas')).toBeVisible();
  await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 30000 });
  await context.setOffline(false);
});
