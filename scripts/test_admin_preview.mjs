// Run with Playwright available, against python3 -m http.server 8765 --directory server.
// Optional --workbook /path/to/downloaded.xlsm tests the real public workbook layout.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
const workbookArg = process.argv.indexOf('--workbook');
const workbook = workbookArg >= 0 ? await readFile(process.argv[workbookArg + 1]) : null;
const published = workbook ? new Map([
  ['927514227', 'beacons.csv'], ['161422711', 'needs-review.csv'], ['1409941161', 'review-details.csv'],
  ['128371500', 'locations.csv'], ['2091204006', 'trails.csv'], ['594422987', 'trail-stops.csv'], ['15659970', null]
]) : null;
const origin = process.env.ADMIN_TEST_URL || 'http://127.0.0.1:8765';
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const errors = []; const writes = [];
page.on('pageerror', e => errors.push(e.message));
page.on('request', r => { if (!['GET', 'HEAD', 'OPTIONS'].includes(r.method())) writes.push(r.url()); });
let failSource = false;
await page.route('https://docs.google.com/spreadsheets/**', async route => {
  const gid = new URL(route.request().url()).searchParams.get('gid'), file = published?.get(gid);
  if (!failSource && file) return route.fulfill({ body: await readFile(new URL(`../server/admin/data/${file}`, import.meta.url)), contentType: 'text/csv', headers: { 'access-control-allow-origin': '*' } });
  if (!failSource && gid === '15659970') return route.fulfill({ body: Buffer.from('topic,guidance\nTest,Test guide'), contentType: 'text/csv', headers: { 'access-control-allow-origin': '*' } });
  return route.abort();
});
await page.route('https://tile.openstreetmap.org/**', route => route.abort());
try {
  await page.goto(`${origin}/admin/`);
  await page.waitForFunction(() => document.querySelectorAll('.point-row').length > 0);
  await page.waitForFunction(() => document.querySelector('#refresh').textContent === 'Refresh now');
  assert.equal(await page.locator('.metric strong').first().textContent(), '64');
  assert.equal(await page.locator('.metric').nth(3).textContent(), '0possible matches');
  assert.equal(await page.locator('.metric').nth(4).textContent(), '57ID-confirmed');
  assert.match(await page.locator('#edit-sheet').getAttribute('href'), /docs\.google\.com\/spreadsheets\/d\/1Pl3uBhqcJbEpxifa4ko2-RpFK4rOT44P/);
  assert.match(await page.locator('#source-file').getAttribute('href'), /2PACX-1vSMJCZSfRryLyZQKeRjpp3Ex9Mt2ALf6HjvgmbuhuE8fFVbADVswl6hhH7glCrxtio9Mp8n65dTv_Ly/);
  assert.equal(await page.locator('.leaflet-interactive').count() >= 49, true);
  assert.match(await page.locator('#source-mode').textContent(), workbook ? /Live published Google Sheet/ : /CSV fallback/);

  await page.locator('#location').selectOption('lions-pride-park');
  assert.equal(await page.locator('.point-row').count() > 0, true);
  assert.match(await page.locator('#filter-map-note').textContent(), /6 relevant trail segments/);
  assert.equal(await page.locator('#map path[stroke="#247c91"]').count(), 6, 'Location filter should retain only its configured routes');
  await page.locator('#location').selectOption('us-202');
  assert.match(await page.locator('#filter-map-note').textContent(), /5 relevant trail segments/);
  assert.equal(await page.locator('#map path[stroke="#247c91"]').count(), 5);
  await page.locator('#location').selectOption('__missing');
  assert.match(await page.locator('#filter-map-note').textContent(), /4 relevant trail segments/);
  assert.equal(await page.locator('#map path[stroke="#247c91"]').count(), 4);
  await page.locator('#clear-filters').click();

  await page.locator('[data-view="diff-view"]').click();
  assert.equal(await page.locator('#diff-summary .diff-stat').count(), 6);
  assert.equal(await page.locator('#diff-filter').count(), 0, 'The summary counts replace the dropdown');
  assert.match(await page.locator('#diff-view').textContent(), /four change types add up to Changed/);
  assert.deepEqual(await page.locator('#diff-summary .diff-stat strong').allTextContents(), ['64', '38', '36', '1', '1', '0']);
  assert.equal(await page.locator('#diff-summary .diff-stat[aria-pressed="true"] span').textContent(), 'Changed');
  assert.equal(await page.locator('#app-diff .diff-card').count(), 38);
  assert.match(await page.locator('#diff-view').textContent(), /Current app.*Master sheet/s);
  await page.locator('[data-diff-filter="identity"]').click();
  assert.equal(await page.locator('#app-diff .diff-card').count(), 1);
  assert.match(await page.locator('#app-diff').textContent(), /Rain Barrels/);
  assert.match(await page.locator('#app-diff').textContent(), /warning, not a confirmed join/);
  assert.equal(await page.locator('#app-diff .leaflet-container').count(), 0, 'Collapsed diffs must not initialize maps');
  await page.locator('#app-diff .diff-card > summary').click();
  await page.waitForFunction(() => document.querySelector('#app-diff .diff-map')?.classList.contains('leaflet-container'));
  assert.match(await page.locator('#app-diff .diff-map-panel').textContent(), /Current app.*Master sheet.*KML remains the final map authority/s);
  assert.equal(await page.locator('#app-diff .diff-map path').count() >= 3, true, 'Old pin, new pin and connecting line should be visible');
  await page.locator('[data-diff-filter="changed"]').click();
  assert.equal(await page.locator('#app-diff .diff-card').count(), 36);
  assert.equal(await page.locator('#app-diff .diff-card').first().locator('.diff-status').count() >= 2, true, 'Field tags should remain visible');
  await page.locator('#app-diff .diff-card').filter({ has: page.locator('.diff-status.location-change') }).nth(0).locator('summary').click();
  await page.waitForFunction(() => document.querySelectorAll('#app-diff .leaflet-container').length === 1);
  await page.locator('#app-diff .diff-card').filter({ has: page.locator('.diff-status.location-change') }).nth(1).locator('summary').click();
  await page.waitForFunction(() => document.querySelectorAll('#app-diff .diff-card[open]').length === 1 && document.querySelectorAll('#app-diff .leaflet-container').length === 1);
  assert.equal(await page.locator('#app-diff .diff-card[open]').count(), 1, 'Only one diff may be expanded');
  assert.equal(await page.locator('#app-diff .leaflet-container').count(), 1, 'Closing a diff must remove its map');
  await page.locator('[data-diff-filter="all"]').click();
  assert.equal(await page.locator('#app-diff .diff-card').count(), 64);
  await page.locator('[data-diff-filter="changes"]').click();

  const checks = await page.evaluate(async () => {
    const d = await import('./data.mjs');
    const kml = d.parseKml(await (await fetch('../talking-trails.kml')).text());
    const manifest = await (await fetch('data/snapshot.json')).json(); const tables = {};
    for (const [name, file] of Object.entries(manifest.files)) tables[name] = d.parseCsv(await (await fetch(`data/${file}`)).text());
    const app = await (await fetch('../warrington-trails.json')).json();
    const master = d.normalize(tables), entries = d.reconcile(master, kml, app);
    const parsed = d.parseCsv('recordKey,name,Minor\r\na,"A, B\nC ""quoted""",1\r\n');
    const blanks = d.position('', '');
    let badCSV = false, badXML = false, badSchema = false;
    try { d.parseCsv('id,id\n1,2'); } catch { badCSV = true; }
    try { d.parseKml('<!DOCTYPE kml><kml/>'); } catch { badXML = true; }
    try { d.normalize({ Beacons: [{ name: 'x' }] }); } catch { badSchema = true; }
    const synthetic = d.normalize({ Beacons: [{ recordKey: 'a', Minor: '1.0', name: 'A', location: 'park', Status: 'Working', 'App Inclusion': 'Active', latitude: '40', longitude: '-75', kmlPlacemarkId: 'p' }], Locations: [{ id: 'park', Major: '17' }] });
    const point = { kmlId: 'p', name: 'renamed', position: [40, -75], data: {} };
    const confirmed = d.reconcile(synthetic, { points: [point] }, null)[0];
    const duplicates = d.reconcile({ ...synthetic, beacons: [...synthetic.beacons, { ...synthetic.beacons[0] }] }, { points: [point] }, null);
    const mismatch = d.reconcile(synthetic, { points: [{ ...point, data: { recordKey: 'different' } }] }, null)[0];
    return { points: kml.points.length, routes: kml.routes.length, entries: entries.length, stops: master.stops.length, appMatches: entries.filter(e => e.app).length,
      gaps: entries.filter(e => e.gap > 75).map(e => e.p.name).sort(), rounding: entries.filter(e => e.coordinateChange?.kind === 'Consistent with rounding').length,
      csv: parsed[0].name, blanks, badCSV, badXML, badSchema, confirmed: confirmed.state, duplicateConfirmed: duplicates.some(e => e.state === 'confirmed'), mismatch: mismatch.state };
  });
  assert.deepEqual(checks, { points: 49, routes: 15, entries: 64, stops: 30, appMatches: 39, gaps: ['Fish', 'Reptiles', 'Wetlands'], rounding: 7,
    csv: 'A, B\nC "quoted"', blanks: null, badCSV: true, badXML: true, badSchema: true, confirmed: 'confirmed', duplicateConfirmed: false, mismatch: 'conflict' });

  await page.locator('#search').fill('Reptiles'); assert.equal(await page.locator('.point-row').count(), 1);
  assert.equal(await page.locator('#filter-map-note').isVisible(), true);
  assert.equal(await page.locator('#map .leaflet-interactive').count(), 1, 'Only the filtered point should remain; KML routes must be hidden');
  await page.locator('.point-row').click(); assert.match(await page.locator('#detail').textContent(), /1,?967|1967/);
  assert.match(await page.locator('#detail').textContent(), /ID confirmed/);
  assert.equal(await page.locator('#detail .copy-id').count(), 0);
  assert.match(await page.locator('#detail').textContent(), /Source Major|Minor/);
  await page.locator('[data-view="review-view"]').click(); assert.equal(await page.locator('.review-card').count(), 6);
  assert.match(await page.locator('#review-checks').textContent(), /rounding — 7 points/);
  await page.locator('.review-card-action').first().click();
  assert.equal(await page.locator('#map-view').isVisible(), true); assert.equal(await page.locator('#review-filter').isVisible(), true);
  assert.equal(await page.locator('.point-row').count(), 40); assert.match(await page.locator('#detail').textContent(), /Map identity/);
  assert.match(await page.locator('.point-row').first().locator('.point-tags').textContent(), /D1.*D3/);
  assert.equal(await page.locator('.point-row').first().locator('.decision-tag.active').textContent(), 'D1');
  await page.locator('#clear-review-filter').click(); assert.equal(await page.locator('.point-row').count(), 64);
  assert.equal(await page.locator('#filter-map-note').isHidden(), true);
  await page.locator('[data-view="tables-view"]').click(); await page.locator('#table-select').selectOption('Beacons');
  assert.equal(await page.locator('#source-table tbody tr').count(), 64);
  if (workbook) {
    failSource = true; await page.locator('#refresh').click();
    await page.waitForFunction(() => document.querySelector('#source-mode').textContent.startsWith('Stale'));
    assert.equal(await page.locator('.metric strong').first().textContent(), '64');
  }
  await page.locator('[data-view="sources-view"]').click();
  await page.locator('#local-file').setInputFiles({ name: 'local.csv', mimeType: 'text/csv', buffer: Buffer.from('recordKey,name,Minor,location,Status,App Inclusion,latitude,longitude,kmlPlacemarkId,description,longDescription\nx,"<img src=x onerror=alert(1)>",999,us-202,Working,Active,40.25,-75.17,,Hello,World\n') });
  await page.waitForFunction(() => document.querySelector('#source-mode').textContent.startsWith('Local file:'));
  assert.equal(await page.locator('#auto-refresh').isDisabled(), true);
  await page.locator('[data-view="map-view"]').click(); await page.locator('#clear-filters').click(); await page.locator('#search').fill('999');
  assert.equal(await page.locator('.point-row').count(), 1); await page.locator('.point-row').click();
  assert.equal(await page.locator('#detail h2 img').count(), 0); assert.match(await page.locator('#detail h2').textContent(), /<img/);
  assert.match(await page.locator('#detail').textContent(), /standalone location point/);
  await page.locator('[data-view="sources-view"]').click();
  await page.locator('#local-file').setInputFiles({ name: 'bad.csv', mimeType: 'text/csv', buffer: Buffer.from('bad,headers\na,b') });
  await page.waitForFunction(() => document.querySelector('#local-error').textContent.includes('File not loaded'));
  assert.equal(await page.locator('.metric strong').first().textContent(), '1');
  await page.locator('#restore-live').click(); await page.waitForFunction(() => document.querySelector('#source-mode').textContent.startsWith('CSV fallback'));
  assert.equal(await page.locator('.metric strong').first().textContent(), '64');
  await page.setViewportSize({ width: 390, height: 844 }); await page.locator('[data-view="map-view"]').click(); await page.locator('#clear-filters').click();
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1), true, 'Mobile page must not overflow horizontally');
  assert.deepEqual(errors, []); assert.deepEqual(writes, []);
  console.log('PASS: workbook/CSV parsing, 49 KML points, 15 routes, 64 records, 39 app matches, 7 rounding cases, 3 placement gaps, ID conflicts, stale/fallback, local preview, XSS safety, mobile layout, read-only requests.');
} finally { await browser.close(); }
