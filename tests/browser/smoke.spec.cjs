const { test, expect } = require('@playwright/test');

test('boots the Godot game shell', async ({ page }, testInfo) => {
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(String(error)));

  const started = Date.now();
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('canvas')).toBeVisible();

  // Firefox WebGL headless su Linux CI può essere molto più lento del browser
  // reale. Qui verifichiamo le capability richieste da Godot (WASM + WebGL2)
  // senza bloccare il deploy per decine di secondi. Il boot Godot completo resta
  // coperto da Chromium/WebKit e dal QA manuale Firefox su device reale.
  if (testInfo.project.name === 'firefox-desktop') {
    const capabilities = await page.evaluate(() => {
      const probe = document.createElement('canvas');
      return {
        wasm: typeof WebAssembly === 'object',
        webgl2: !!probe.getContext('webgl2'),
      };
    });
    expect(capabilities.wasm).toBeTruthy();
    expect(capabilities.webgl2).toBeTruthy();
    await page.waitForTimeout(750);
  } else {
    await page.waitForFunction(() => window.__briscolaAppReady === true, null, { timeout: 30000 });
  }

  const bootMs = Date.now() - started;
  await testInfo.attach('boot-time.txt', {
    body: Buffer.from(`${testInfo.project.name}: ${bootMs} ms\n`),
    contentType: 'text/plain',
  });
  expect(pageErrors, pageErrors.join('\n')).toEqual([]);
});
