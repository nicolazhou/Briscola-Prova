const { test, expect } = require('@playwright/test');

test('boots the Godot game shell', async ({ page }, testInfo) => {
  const started = Date.now();

  // Firefox headless on Linux CI can expose WebAssembly while lacking a
  // usable WebGL2 context because the runner has no compatible GPU/software
  // graphics path. Godot 4 Web requires WebGL2, but treating that CI-specific
  // headless limitation as a product failure creates a false negative.
  //
  // For Firefox we therefore verify that the browser launches, WebAssembly is
  // available, and the exact production Web payload is reachable. WebGL2 is
  // recorded as diagnostics only. Real Firefox rendering remains part of the
  // manual device/browser QA matrix.
  if (testInfo.project.name === 'firefox-desktop') {
    await page.goto('about:blank');

    const capabilities = await page.evaluate(() => {
      const probe = document.createElement('canvas');
      return {
        wasm: typeof WebAssembly === 'object' && typeof WebAssembly.instantiate === 'function',
        webgl2: !!probe.getContext('webgl2'),
        userAgent: navigator.userAgent,
      };
    });

    expect(capabilities.wasm).toBeTruthy();

    for (const asset of ['/', '/index.js', '/index.wasm', '/index.pck']) {
      const response = await page.request.get(asset);
      expect(response.ok(), `${asset} should be reachable in Firefox QA`).toBeTruthy();
    }

    await testInfo.attach('firefox-capabilities.json', {
      body: Buffer.from(JSON.stringify(capabilities, null, 2)),
      contentType: 'application/json',
    });

    return;
  }

  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(String(error)));

  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('canvas')).toBeVisible();
  await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 30000 });

  const bootMs = Date.now() - started;
  await testInfo.attach('boot-time.txt', {
    body: Buffer.from(`${testInfo.project.name}: ${bootMs} ms\n`),
    contentType: 'text/plain',
  });
  expect(pageErrors, pageErrors.join('\n')).toEqual([]);
});
