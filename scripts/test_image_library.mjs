import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const { chromium } = createRequire(import.meta.url)('playwright');
const origin = process.env.IMAGE_LIBRARY_TEST_URL || 'http://127.0.0.1:8765';
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const errors = [];
page.on('pageerror', error => errors.push(error.message));

try {
  await page.goto(`${origin}/images/`);
  await page.waitForFunction(() => [...document.images].every(image => image.complete));
  assert.equal(await page.locator('.card').count(), 36);
  assert.equal(await page.locator('.card:visible').count(), 36);
  assert.equal(await page.locator('img').evaluateAll(images => images.every(image => image.naturalWidth > 0)), true);
  await page.locator('#location').selectOption('us-202');
  assert.equal(await page.locator('.card:visible').count(), 13);
  await page.locator('#search').fill('nesting');
  assert.equal(await page.locator('.card:visible').count(), 1);
  assert.match(await page.locator('.card:visible input').inputValue(), /^https:\/\/trails\.warringtoneac\.org\/us-202\/images\//);
  assert.deepEqual(errors, []);
  await page.locator('#location').selectOption('');
  await page.locator('#search').fill('');
  await page.screenshot({ path: '/tmp/warrington-image-library.png', fullPage: true });
  console.log('Image library browser checks passed.');
} finally {
  await browser.close();
}
