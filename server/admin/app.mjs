import { clean, id, metres, parseCsv, readWorkbook, parseKml, normalize, reconcile, stopIssues, statusOptions, position } from './data.mjs';

const $ = selector => document.querySelector(selector);
const el = (tag, text, className) => { const n = document.createElement(tag); if (text !== undefined) n.textContent = text; if (className) n.className = className; return n; };
const state = { config: null, master: null, kml: { points: [], routes: [], warnings: [] }, app: null, entries: [], selected: null, reviewKeys: null, reviewLabel: '', reviewGroupId: '', mode: 'Loading', messages: [], busy: false, local: false, lastGood: null, fallback: null, snapshot: null, markers: new Map() };
let map, routesLayer, pointsLayer, appLayer, selectionLayer, fitted = false, diffMaps = [], diffFilter = 'changes';

async function get(url, format = 'text') {
  const controller = new AbortController(), timeout = setTimeout(() => controller.abort(), 18000);
  try {
    const response = await fetch(url, { signal: controller.signal, cache: 'no-store', credentials: 'omit' });
    if (!response.ok) throw Error(`HTTP ${response.status}`);
    const reader = response.body.getReader(); const chunks = []; let length = 0;
    for (;;) { const { value, done } = await reader.read(); if (done) break; length += value.length; if (length > 8 * 1024 * 1024) { await reader.cancel(); throw Error('File exceeds 8 MB preview limit.'); } chunks.push(value); }
    const bytes = new Uint8Array(length); let offset = 0; for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    if (format === 'bytes') return bytes;
    const text = new TextDecoder().decode(bytes);
    return format === 'json' ? JSON.parse(text) : text;
  } finally { clearTimeout(timeout); }
}
const date = v => v ? new Date(v).toLocaleString() : 'not loaded';
function link(selector, url) { const n = $(selector); const u = new URL(url, location.href); if (!['http:', 'https:'].includes(u.protocol)) throw Error('Unsupported source URL.'); n.href = u.href; }
function notice(text) { $('#notices').append(el('div', text, 'notice')); }
function sourceStatus() {
  $('#source-mode').textContent = state.mode;
  $('#source-dot').className = `source-dot ${state.mode.startsWith('Live') ? 'live' : 'fallback'}`;
  $('#source-time').textContent = `${state.local ? 'Opened' : 'Last successful read'}: ${date(state.lastGood)}`;
  $('#notices').replaceChildren(); state.messages.forEach(notice);
  if (state.master?.legacy) notice('This workbook still has legacy Trail Coordinates. Only its landmark-linked stops are used here; map shapes come exclusively from KML.');
  if (state.master && 'beaconStatus' in state.master.beacons[0].raw) notice('Older workbook columns detected. Status labels are translated for this preview; original wording remains visible in point details and Sheet tables. The shared file has not been changed.');
  state.kml.warnings.forEach(notice);
}
function options(selector, values) {
  const n = $(selector), current = n.value, first = n.options[0].cloneNode(true); n.replaceChildren(first);
  for (const [value, label] of values) { const o = el('option', label); o.value = value; n.append(o); }
  if (Array.from(n.options).some(o => o.value === current)) n.value = current;
}
function rebuild() {
  if (!state.master) return;
  state.entries = reconcile(state.master, state.kml, state.app);
  options('#location', [...new Set(state.master.beacons.map(b => b.location))].sort().map(v => [v || '__missing', state.master.locations.find(l => l.id === v)?.name ?? (v || 'Unassigned location')]));
  options('#hardware', [...statusOptions, 'Unspecified'].map(v => [v, v]));
  const metrics = [[state.master.beacons.length, 'sheet records'], [state.kml.points.length, 'KML points'], [state.kml.routes.length, 'route segments'], [state.entries.filter(e => e.state === 'candidate').length, 'possible matches'], [state.entries.filter(e => e.state === 'confirmed').length, 'ID-confirmed'], [state.entries.filter(e => e.gap > 75).length, 'position gaps >75 m']];
  $('#metrics').replaceChildren(...metrics.map(([n, label]) => { const box = el('div', undefined, 'metric'); box.append(el('strong', String(n)), el('span', label)); return box; }));
  drawRoutes(); renderPoints(); renderAppDiff(); renderReview(); renderTables(); renderSources(); sourceStatus();
  if (state.selected && state.entries.some(e => e.uid === state.selected)) selectPoint(state.selected, false);
}
function switchView(target) {
  document.querySelectorAll('.view').forEach(n => n.hidden = n.id !== target);
  document.querySelectorAll('[data-view]').forEach(n => n.setAttribute('aria-pressed', String(n.dataset.view === target)));
  if (target === 'map-view' && map) requestAnimationFrame(() => map.invalidateSize());
}
function visibleEntries() {
  const q = $('#search').value.toLowerCase(), locationFilter = $('#location').value, hardware = $('#hardware').value, scope = $('#scope').value;
  return state.entries.filter(e => {
    const b = e.b;
    if (state.reviewKeys && (!b || !state.reviewKeys.has(b.key))) return false;
    if (q && ![e.p?.name, b?.name, b?.minor, b?.key, e.p?.kmlId].some(v => String(v ?? '').toLowerCase().includes(q))) return false;
    if (locationFilter && (b?.location || '__missing') !== locationFilter) return false;
    if (hardware && (b?.status || 'Unspecified') !== hardware) return false;
    if (scope === 'placement') return e.gap > 75;
    if (scope === 'unlinked') return !e.p || !b;
    if (scope === 'candidate' || scope === 'confirmed') return e.state === scope;
    if (scope === 'retired') return b?.inclusion === 'Retired';
    if (scope === 'no-position') return !e.position;
    if (scope === 'standalone') return !!b && !e.stops.length;
    return true;
  });
}
function pointFiltersActive() {
  return !!state.reviewKeys || ['#search', '#location', '#hardware', '#scope'].some(selector => $(selector).value !== '');
}
function visibleRoutes() {
  const locationId = $('#location').value;
  if (locationId) {
    const kmlLocation = locationId === '__missing' ? 'unassigned' : locationId;
    return state.kml.routes.filter(route => route.location === kmlLocation);
  }
  return pointFiltersActive() ? [] : state.kml.routes;
}
function pointColor(e) { if (!e.b || e.b.inclusion === 'Retired' || e.b.status === 'To be purchased') return '#718492'; return e.b.status === 'Working' ? '#13815c' : '#ac660b'; }
function matchLabel(e) {
  if (e.state === 'confirmed') return 'ID confirmed';
  if (e.state === 'candidate') return 'Possible match · confirm ID';
  if (e.state === 'conflict') return 'Link conflict · review';
  if (e.p && !e.b) return 'KML point only';
  if (e.b && !e.p) return 'Sheet row only';
  return 'Not linked';
}
function decisionTags(beacon) {
  if (!beacon) return [];
  return state.master.groups.filter(group => new Set(clean(group.affectedRecordKeys).split(',').map(clean)).has(beacon.key)).map(group => ({ id: id(group.group), label: group.decision }));
}
function initMap() {
  if (!window.L) { $('#map-error').hidden = false; $('#map-error').textContent = 'Map library could not load. The point list and source tables remain available.'; return; }
  map = L.map('map', { scrollWheelZoom: true }).setView([40.245, -75.17], 14);
  const tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' }).addTo(map);
  tiles.on('tileerror', () => { $('#map-error').hidden = false; $('#map-error').textContent = 'Street-map tiles are unavailable. KML shapes and points still work.'; });
  routesLayer = L.layerGroup().addTo(map); pointsLayer = L.layerGroup().addTo(map); appLayer = L.layerGroup().addTo(map); selectionLayer = L.layerGroup().addTo(map);
}
function drawRoutes() {
  if (!map) return; routesLayer.clearLayers(); appLayer.clearLayers();
  const filtering = pointFiltersActive(), routes = visibleRoutes(), locationId = $('#location').value, note = $('#filter-map-note');
  note.hidden = !filtering;
  if (locationId) {
    const locationName = $('#location').selectedOptions[0]?.textContent ?? locationId;
    note.textContent = routes.length ? `${routes.length} relevant trail segments shown for ${locationName}.` : `No trail mapping is configured for ${locationName}.`;
  } else note.textContent = 'Trail lines are hidden while point filters are active.';
  for (const r of routes) L.polyline(r.coordinates, { color: '#247c91', weight: 4, opacity: .8 }).bindTooltip(el('span', `${r.name} · ${r.coordinates.length} vertices`)).addTo(routesLayer);
  const appPoints = filtering ? visibleEntries().map(e => e.app).filter(Boolean) : state.app?.landmarks ?? [];
  if ($('#show-app').checked) for (const a of appPoints) {
    const p = position(a.coordinates?.latitude, a.coordinates?.longitude); if (!p) continue;
    L.circleMarker(p, { radius: 5, color: '#6652a0', fillOpacity: .3, weight: 2 }).bindTooltip(el('span', `Current app: ${a.name} · Minor ${a.id}`)).addTo(appLayer);
  }
}
function fitMap() {
  if (!map) return;
  const p = visibleEntries().filter(e => e.position).map(e => e.position);
  if ($('#location').value) visibleRoutes().forEach(r => p.push(...r.coordinates));
  if (!p.length && !pointFiltersActive()) state.kml.routes.forEach(r => p.push(...r.coordinates));
  if (p.length) map.fitBounds(p, { padding: [35, 55], maxZoom: 17 });
}
function renderPoints() {
  const entries = visibleEntries(); $('#list-count').textContent = `${entries.length} points`;
  const queue = $('#review-filter'); queue.hidden = !state.reviewKeys;
  if (state.reviewKeys) { $('#review-filter-title').textContent = `Review queue: ${state.reviewLabel}`; $('#review-filter-count').textContent = `${entries.length} affected points`; }
  $('#points').replaceChildren(); pointsLayer?.clearLayers(); state.markers.clear(); drawRoutes();
  if (state.selected && !entries.some(e => e.uid === state.selected)) {
    state.selected = null; selectionLayer?.clearLayers();
    $('#detail').innerHTML = '<div class="empty"><h2>Select a point</h2><p>Choose a visible pin or row to read its details.</p></div>';
  }
  if (!entries.length) $('#points').append(el('p', 'No points match these filters.', 'empty'));
  for (const e of entries) {
    const row = el('button', undefined, 'point-row'); row.type = 'button'; row.dataset.uid = e.uid; row.setAttribute('aria-pressed', String(state.selected === e.uid));
    row.append(el('strong', e.b?.name || e.p?.name || 'Unnamed point'), el('small', e.b ? `${e.b.key || 'No record ID'} · Minor ${e.b.minor || 'not set'} · ${e.b.status || 'No hardware status'}` : 'KML only · no sheet record'));
    const groups = decisionTags(e.b);
    if (groups.length) {
      const tags = el('span', undefined, 'point-tags');
      groups.forEach(group => { const tag = el('span', `D${group.id}`, `decision-tag${group.id === state.reviewGroupId ? ' active' : ''}`); tag.title = group.label; tags.append(tag); });
      row.append(tags);
    }
    row.append(el('small', e.gap > 75 ? `${Math.round(e.gap).toLocaleString()} m position gap · ${matchLabel(e)}` : e.position ? matchLabel(e) : `${matchLabel(e)} · no coordinates`, e.state === 'confirmed' ? '' : 'issue-label'));
    row.addEventListener('click', () => selectPoint(e.uid)); $('#points').append(row);
    if (map && e.position) {
      const marker = L.circleMarker(e.position, { radius: state.selected === e.uid ? 10 : 7, weight: 2, color: pointColor(e), fillColor: e.p ? pointColor(e) : '#fff', fillOpacity: .95 });
      marker.bindTooltip(el('span', `${e.b?.name || e.p?.name} · ${matchLabel(e)}`)); marker.on('click', () => selectPoint(e.uid, false)); marker.addTo(pointsLayer); state.markers.set(e.uid, marker);
    }
  }
  if (!fitted && map && entries.some(e => e.position)) { fitMap(); fitted = true; }
}
function clearFilters(clearQueue = true) {
  for (const selector of ['#search', '#location', '#hardware', '#scope']) $(selector).value = '';
  if (clearQueue) { state.reviewKeys = null; state.reviewLabel = ''; state.reviewGroupId = ''; }
  renderPoints(); fitMap();
}
function startReviewQueue(keys, label, groupId = '') {
  state.reviewKeys = new Set(keys); state.reviewLabel = label; state.reviewGroupId = groupId;
  clearFilters(false); switchView('map-view');
  const first = visibleEntries()[0]; if (first) selectPoint(first.uid);
}
function section(title) { const n = el('section', undefined, 'detail-section'); n.append(el('h3', title)); return n; }
function facts(pairs) { const dl = el('dl'); for (const [k, v] of pairs) { dl.append(el('dt', k), el('dd', clean(v) || 'Not set')); } return dl; }
function selectPoint(uid, pan = true) {
  const e = state.entries.find(e => e.uid === uid); if (!e) return;
  state.selected = uid;
  document.querySelectorAll('.point-row').forEach(n => n.setAttribute('aria-pressed', String(n.dataset.uid === uid)));
  state.markers.forEach((m, key) => m.setRadius(key === uid ? 10 : 7));
  selectionLayer?.clearLayers();
  if (map && e.position && pan) map.setView(e.position, Math.max(map.getZoom(), 16));
  const detail = $('#detail'); detail.replaceChildren();
  const b = e.b; detail.append(el('span', b?.key || 'KML POINT', 'eyebrow'), el('h2', b?.name || e.p?.name || 'Unnamed point'));
  detail.append(el('span', matchLabel(e), `badge ${e.state === 'confirmed' ? 'ok' : 'warn'}`));
  if (b) detail.append(el('span', b.status || 'Status not set', 'badge'), el('span', b.inclusion || 'Inclusion not set', 'badge'));
  const identity = section('Map identity');
  identity.append(facts([['KML name', e.p?.name], ['KML ID', e.p?.kmlId], ['Link basis', e.reason], ['Pin position', e.p ? 'KML (read-only)' : e.position ? 'Sheet fallback' : 'Not placed'], ['KML lat / lon', e.p?.position.join(', ')], ['Sheet lat / lon', b?.position?.join(', ')], ['Position gap', e.gap === null ? '' : `${e.gap.toFixed(1)} m`]]));
  if (e.p && b && e.state !== 'confirmed') {
    identity.append(el('p', 'After verifying this is the same point, copy the KML ID into this row’s kmlPlacemarkId column in the sheet. This preview does not approve or save the link.', 'muted'));
    const copy = el('button', 'Copy KML ID', 'copy-id'); copy.type = 'button';
    copy.addEventListener('click', async () => { try { await navigator.clipboard.writeText(e.p.kmlId); copy.textContent = 'KML ID copied'; } catch { copy.textContent = `KML ID: ${e.p.kmlId}`; } });
    identity.append(copy);
  }
  detail.append(identity);
  if (map && e.p && b?.position) {
    L.polyline([e.p.position, b.position], { color: '#b5670b', weight: 2, dashArray: '5 5' }).addTo(selectionLayer);
    L.circleMarker(b.position, { color: '#b5670b', fillColor: '#fff', fillOpacity: 1, radius: 5 }).bindTooltip(el('span', 'Sheet coordinate (comparison)')).addTo(selectionLayer);
  }
  if (!b) { detail.append(el('p', 'No unique sheet record is linked to this point. Add or confirm its permanent identity in the master sheet.')); return; }
  const info = section('Beacon & location'); info.append(facts([['Minor', b.minor], ['Source Minor', b.sourceMinor], ['Major', e.location?.major], ['Source Major', b.sourceMajor], ['Location', e.location?.name || b.location], ['Location code', b.sourceLocationCode], ['Purchase count', b.purchaseCount], ['Source status', b.sourceStatus], ['Placement', b.beaconPlacement]]));
  if (clean(b.sourceStatus).toLowerCase().includes("can't locate")) info.append(el('p', '“Can’t locate” is displayed as Missing, but absence has not been confirmed.', 'muted'));
  if (b.hardwareNotes) info.append(el('p', b.hardwareNotes, 'muted')); detail.append(info);
  const content = section('App text');
  if (b.imagePath) {
    const url = new URL(b.imagePath, new URL('../', location.href));
    if (url.origin === location.origin && url.pathname.startsWith(new URL('../', location.href).pathname)) {
      const img = el('img'); img.src = url.href; img.alt = b.imageAlt || b.name; img.loading = 'lazy'; img.addEventListener('error', () => img.replaceWith(el('p', 'Image unavailable at the sheet path.', 'muted'))); content.append(img);
    }
  }
  content.append(el('p', b.description || 'Short text is not set.', 'text-content'), el('p', b.longDescription || 'Long text is not set.', 'text-content')); detail.append(content);
  const stops = section('Trail stops');
  if (!e.stops.length) stops.append(el('p', 'No listed trail stops. This can be a standalone location point; a trail is not required.'));
  for (const s of e.stops) {
    const tr = state.master.trails.find(t => t.id === s.trailId), d = el('details');
    d.append(el('summary', `${tr?.name || s.trailId} · stop ${s.order ?? '?'}`), el('p', `Forward ${s.forwardDistance}: ${s.forward || 'No instructions'}`), el('p', `Reverse ${s.reverseDistance}: ${s.reverse || 'No instructions'}`)); stops.append(d);
  } detail.append(stops);
  const diff = section('Master vs current app');
  if (!state.app) diff.append(el('p', 'App JSON unavailable; comparison is not complete.'));
  else if (!e.app) diff.append(el('p', 'No unique app record matches this location and Minor. Review identity before treating it as new.'));
  else {
    diff.append(el('p', `${e.coordinateChange.kind}${e.coordinateChange.distance === null ? '' : ` · ${e.coordinateChange.distance.toFixed(1)} m`}`));
    if (e.coordinateChange.kind === 'Consistent with rounding') diff.append(el('p', 'Both original coordinates round to the sheet’s written precision. This supports rounding, but does not prove how the point was measured.', 'muted'));
    for (const change of e.changes) { const d = el('details'); d.append(el('summary', change.field), el('strong', 'Current app'), el('p', change.before || '(blank)', 'text-content'), el('strong', 'Master sheet'), el('p', change.after || '(blank)', 'text-content')); diff.append(d); }
    if (!e.changes.length) diff.append(el('p', 'Text, image and category fields match after whitespace normalization.'));
  } detail.append(diff);
  if (e.issues.length) { const s = section('Review notes'), ul = el('ul'); e.issues.forEach(i => ul.append(el('li', i.text))); s.append(ul); if (b.reviewNotes) s.append(el('p', b.reviewNotes, 'muted')); detail.append(s); }
  const edit = el('a', 'Open master sheet ↗', 'button'); edit.href = $('#edit-sheet').href; edit.target = '_blank'; edit.rel = 'noopener noreferrer'; detail.append(edit);
}

const appFieldDefinitions = [
  ['Name', a => a?.name, b => b?.name],
  ['Location', a => a?.location, b => b?.location],
  ['Minor', a => id(a?.id), b => b?.minor],
  ['Category', a => a?.category, b => b?.category],
  ['Short description', a => a?.description, b => b?.description],
  ['Long description', a => a?.longDescription, b => b?.longDescription],
  ['Image path', a => a?.imagePath, b => b?.imagePath],
  ['Image description', a => a?.imageAlt, b => b?.imageAlt],
  ['Trail open', a => a?.isOpen, b => b?.isOpen],
  ['Trail summary', a => a?.trailDistanceDescription, b => b?.trailDistanceDescription],
  ['Coordinates', a => position(a?.coordinates?.latitude, a?.coordinates?.longitude)?.join(', '), b => b?.position?.join(', ')]
];
const diffValue = value => typeof value === 'boolean' ? String(value) : clean(value);
const sameDiffValue = (before, after) => diffValue(before).replace(/\s+/g, ' ') === diffValue(after).replace(/\s+/g, ' ');
function comparedFields(app, beacon, coordinateKind) {
  return appFieldDefinitions.map(([label, beforeValue, afterValue]) => {
    const before = diffValue(beforeValue(app)), after = diffValue(afterValue(beacon));
    return { label, before, after, changed: !sameDiffValue(before, after), rounding: label === 'Coordinates' && coordinateKind === 'Consistent with rounding' };
  });
}
function comparisonTags(kind, label, fields, hasRounding) {
  const tags = [{ key: kind, label }], labels = new Set(fields.map(field => field.label));
  if (['Short description', 'Long description', 'Trail summary'].some(field => labels.has(field))) tags.push({ key: 'text', label: 'Text' });
  if (['Image path', 'Image description'].some(field => labels.has(field))) tags.push({ key: 'image', label: 'Image' });
  if (['Location', 'Coordinates'].some(field => labels.has(field))) tags.push({ key: 'location-change', label: 'Location' });
  if (hasRounding) tags.push({ key: 'rounding', label: 'Rounding note' });
  return tags;
}
function appDiffRows() {
  if (!state.app || !state.master) return [];
  const usedApps = new Set(), seenBeacons = new Set(), rows = [];
  const entries = state.entries.filter(e => {
    if (!e.b) return false;
    const key = e.b.key ? `key:${e.b.key}` : `uid:${e.uid}`;
    if (seenBeacons.has(key)) return false; seenBeacons.add(key); return true;
  });
  const sheetMinorCounts = new Map();
  for (const e of entries) if (e.b.minor) sheetMinorCounts.set(e.b.minor, (sheetMinorCounts.get(e.b.minor) ?? 0) + 1);
  for (const e of entries) {
    const b = e.b; let app = e.app, uncertainIdentity = false;
    if (!app && b.minor && sheetMinorCounts.get(b.minor) === 1) {
      const possible = state.app.landmarks.filter(a => id(a.id) === b.minor && !usedApps.has(a));
      if (possible.length === 1) { app = possible[0]; uncertainIdentity = true; }
    }
    if (app) usedApps.add(app);
    let fields = comparedFields(app, b, e.coordinateChange?.kind).filter(f => f.changed);
    const hasRounding = fields.some(f => f.rounding);
    let kind, label, explanation;
    if (b.inclusion === 'Draft') {
      kind = 'draft'; label = 'Draft · not deploying'; explanation = app ? 'This currently exists in the app but the master marks it Draft. Confirm before the next export removes it.' : 'This planned row stays out of the next app export.';
      fields = [{ label: 'App inclusion', before: app ? 'In current app' : '(not in current app)', after: 'Draft · excluded from export', changed: true }, ...fields];
    } else if (app && b.inclusion === 'Retired') {
      kind = 'retiring'; label = 'Leaving the app'; explanation = 'The current app contains this record, while the master marks it Retired.';
      fields = [{ label: 'App inclusion', before: 'In current app', after: 'Retired · excluded from export', changed: true }, ...fields];
    } else if (!app && b.inclusion === 'Retired') {
      kind = 'unchanged'; label = 'Already absent'; explanation = 'The master marks this Retired and it is already absent from the current app.'; fields = [];
    } else if (uncertainIdentity) {
      kind = 'identity'; label = 'Identity / location mismatch'; explanation = 'The Minor appears once in each source, but the location does not match. This comparison is a warning, not a confirmed join.';
    } else if (!app) {
      kind = 'unmatched'; label = 'Only in master'; explanation = 'No unique current-app record matches this location and Minor. Verify identity before treating it as a new app point.';
      fields = comparedFields(null, b).filter(f => f.after);
    } else {
      const substantive = fields.filter(f => !f.rounding);
      kind = substantive.length ? 'changed' : 'unchanged'; label = substantive.length ? 'Changed' : hasRounding ? 'No substantive change' : 'No change';
      explanation = hasRounding && !substantive.length ? 'The only coordinate difference is consistent with rounding.' : substantive.length ? `${substantive.length} app field${substantive.length === 1 ? '' : 's'} would change.` : 'The compared app fields match.';
    }
    rows.push({ e, b, app, kind, label, explanation, fields, hasRounding, tags: comparisonTags(kind, label, fields, hasRounding), key: b.key || e.uid });
  }
  for (const app of state.app.landmarks) if (!usedApps.has(app)) {
    const fields = comparedFields(app, null).filter(f => f.before);
    rows.push({ e: null, b: null, app, kind: 'unmatched', label: 'Only in current app', explanation: 'No unique master row matches this location and Minor. Verify identity before removing it.',
      fields, hasRounding: false, tags: comparisonTags('unmatched', 'Only in current app', fields, false), key: `app-${app.location}-${id(app.id)}` });
  }
  return rows.sort((a, b) => (a.b?.name || a.app?.name || '').localeCompare(b.b?.name || b.app?.name || ''));
}
function renderInlineDiffMap(container, row) {
  if (!container.isConnected) return;
  if (container.dataset.ready) { requestAnimationFrame(() => container.diffMap?.invalidateSize()); return; }
  container.dataset.ready = 'true';
  if (!window.L) { container.append(el('p', 'Map unavailable. Coordinates remain visible in the comparison below.', 'empty')); return; }
  const oldPosition = position(row.app?.coordinates?.latitude, row.app?.coordinates?.longitude), newPosition = row.b?.position;
  const points = [oldPosition, newPosition].filter(Boolean); if (!points.length) return;
  const inlineMap = L.map(container, { scrollWheelZoom: false, zoomControl: true, attributionControl: true }); container.diffMap = inlineMap; diffMaps.push(inlineMap);
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' }).addTo(inlineMap);
  if (oldPosition) L.circleMarker(oldPosition, { radius: 8, weight: 3, color: '#9c3028', fillColor: '#d95d52', fillOpacity: .95 }).bindTooltip('Current app').addTo(inlineMap);
  if (newPosition) L.circleMarker(newPosition, { radius: 8, weight: 3, color: '#126543', fillColor: '#2da879', fillOpacity: .95 }).bindTooltip('Master sheet').addTo(inlineMap);
  if (oldPosition && newPosition) L.polyline([oldPosition, newPosition], { color: '#526775', weight: 2, dashArray: '6 6' }).addTo(inlineMap);
  if (points.length === 1) inlineMap.setView(points[0], 16); else inlineMap.fitBounds(points, { padding: [42, 42], maxZoom: 17 });
  requestAnimationFrame(() => inlineMap.invalidateSize());
}
function destroyInlineDiffMap(container) {
  if (!container) return;
  if (container.diffMap) {
    container.diffMap.remove();
    diffMaps = diffMaps.filter(mapInstance => mapInstance !== container.diffMap);
    container.diffMap = null;
  }
  delete container.dataset.ready;
  container.replaceChildren();
}
function renderAppDiff() {
  const root = $('#app-diff'), summary = $('#diff-summary'); diffMaps.forEach(m => m.remove()); diffMaps = []; root.replaceChildren(); summary.replaceChildren();
  if (!state.app) { root.append(el('p', 'Current-app JSON is unavailable, so no comparison can be shown.', 'empty')); return; }
  const rows = appDiffRows(), releaseKinds = new Set(['changed', 'identity', 'retiring', 'unmatched']);
  const definitions = [
    ['all', 'Total', 'All compared records', rows.length, 'total'],
    ['changes', 'Changed', 'Release changes', rows.filter(row => releaseKinds.has(row.kind)).length, 'changed-total'],
    ['changed', 'Updated', 'Existing records updated', rows.filter(row => row.kind === 'changed').length, 'change-type'],
    ['identity', 'Identity', 'Identity mismatch', rows.filter(row => row.kind === 'identity').length, 'change-type'],
    ['retiring', 'Leaving', 'Leaving the app', rows.filter(row => row.kind === 'retiring').length, 'change-type'],
    ['unmatched', 'Added / missing', 'Only in one source', rows.filter(row => row.kind === 'unmatched').length, 'change-type']
  ];
  for (const [filter, label, description, count, group] of definitions) {
    const stat = el('button', undefined, `diff-stat ${group}${diffFilter === filter ? ' active' : ''}`);
    stat.type = 'button'; stat.dataset.diffFilter = filter; stat.setAttribute('aria-pressed', String(diffFilter === filter));
    stat.setAttribute('aria-label', `${label}: ${count}. ${description}`);
    stat.append(el('strong', String(count)), el('span', label), el('small', description));
    stat.addEventListener('click', () => { diffFilter = filter; renderAppDiff(); }); summary.append(stat);
  }
  const q = $('#diff-search').value.toLowerCase();
  const visible = rows.filter(row => {
    const matchesKind = diffFilter === 'all' ? true : diffFilter === 'changes' ? releaseKinds.has(row.kind) : row.kind === diffFilter;
    const matchesSearch = !q || [row.b?.name, row.app?.name, row.b?.key, row.b?.minor, row.app?.id, row.b?.location, row.app?.location].some(value => clean(value).toLowerCase().includes(q));
    return matchesKind && matchesSearch;
  });
  const count = el('p', `${visible.length} of ${rows.length} records shown`, 'diff-count'); root.append(count);
  if (!visible.length) { root.append(el('p', 'No records match this comparison filter.', 'empty')); return; }
  visible.forEach(row => {
    const card = el('details', undefined, `diff-card ${row.kind}`);
    const heading = el('summary'), title = el('span', undefined, 'diff-title'); title.append(el('strong', row.b?.name || row.app?.name || 'Unnamed record'), el('small', `${row.b?.key || 'Current app only'} · Minor ${row.b?.minor || id(row.app?.id) || 'not set'} · ${row.b?.location || row.app?.location || 'no location'}`));
    const statusTags = el('span', undefined, 'diff-status-list');
    row.tags.forEach(tag => statusTags.append(el('span', tag.label, `diff-status ${tag.key}`)));
    heading.append(statusTags, title, el('span', `${row.fields.length} field${row.fields.length === 1 ? '' : 's'}`, 'diff-field-count')); card.append(heading, el('p', row.explanation, 'diff-explanation'));
    const oldPosition = position(row.app?.coordinates?.latitude, row.app?.coordinates?.longitude), newPosition = row.b?.position;
    const showsLocationChange = row.fields.some(field => field.label === 'Coordinates') && (oldPosition || newPosition);
    let mapContainer;
    if (showsLocationChange) {
      const mapPanel = el('section', undefined, 'diff-map-panel'), mapHeading = el('div', undefined, 'diff-map-heading');
      const distance = oldPosition && newPosition ? metres(oldPosition, newPosition) : null;
      mapHeading.append(el('strong', 'Location comparison'), el('span', distance === null ? 'One source has no coordinates' : distance < .05 ? 'Same position' : `${distance.toFixed(1)} m apart`));
      const legend = el('div', undefined, 'diff-map-legend'); legend.append(el('span', 'Current app', 'old'), el('span', 'Master sheet', 'new'), el('small', 'KML remains the final map authority.'));
      mapContainer = el('div', undefined, 'diff-map'); mapContainer.setAttribute('aria-label', `Location comparison for ${row.b?.name || row.app?.name || 'record'}`);
      mapPanel.append(mapHeading, mapContainer, legend); card.append(mapPanel);
    }
    card.addEventListener('toggle', () => {
      if (card.open) {
        root.querySelectorAll('.diff-card[open]').forEach(other => { if (other !== card) other.open = false; });
        if (mapContainer) renderInlineDiffMap(mapContainer, row);
      } else destroyInlineDiffMap(mapContainer);
    });
    if (row.fields.length) {
      const columns = el('div', undefined, 'diff-columns diff-column-head'); columns.append(el('span', 'Field'), el('span', '− Current app'), el('span', '+ Master sheet')); card.append(columns);
      for (const field of row.fields) {
        const line = el('div', undefined, `diff-columns diff-line${field.rounding ? ' rounding' : ''}`);
        line.append(el('strong', field.rounding ? `${field.label} · rounding` : field.label), el('pre', field.before || '(blank)', 'diff-before'), el('pre', field.after || '(blank)', 'diff-after')); card.append(line);
      }
    }
    const actions = el('div', undefined, 'diff-actions');
    if (row.e) { const mapButton = el('button', 'Open on map'); mapButton.type = 'button'; mapButton.addEventListener('click', () => { switchView('map-view'); selectPoint(row.e.uid); }); actions.append(mapButton); }
    if (row.b) { const sheet = el('a', 'Open master sheet ↗', 'button'); sheet.href = $('#edit-sheet').href; sheet.target = '_blank'; sheet.rel = 'noopener noreferrer'; actions.append(sheet); }
    card.append(actions); root.append(card);
  });
}

function table(headers, rows, clickable = false) {
  const t = el('table'), head = el('thead'), hr = el('tr'); headers.forEach(h => hr.append(el('th', h))); head.append(hr); t.append(head);
  const body = el('tbody');
  rows.forEach(values => { const tr = el('tr'); values.forEach((v, i) => { const td = el('td'); if (clickable && i === 0) { const b = el('button', v.label); b.addEventListener('click', () => { switchView('map-view'); selectPoint(v.uid); $('#detail').scrollIntoView({ block: 'nearest' }); }); td.append(b); } else { td.textContent = clean(v); if (clean(v).length > 140) td.className = 'long'; } tr.append(td); }); body.append(tr); });
  t.append(body); return t;
}
function renderReview() {
  const root = $('#review-groups'); root.replaceChildren();
  for (const g of state.master.groups) {
    const card = el('article', undefined, 'review-card'); card.append(el('span', `DECISION ${id(g.group)} · ${g.status || 'Open'}`, 'eyebrow'), el('h3', g.decision), el('p', g.whatResolvesIt));
    const keys = new Set(clean(g.affectedRecordKeys).split(',').map(clean));
    const affected = state.master.beacons.filter(b => keys.has(b.key));
    card.append(el('small', `${affected.length} currently loaded records. A point may appear in more than one bulk decision.`));
    if (g.resolution) card.append(el('p', `Recorded resolution: ${g.resolution}`));
    const open = el('button', `Review ${affected.length} affected points`, 'review-card-action'); open.type = 'button'; open.disabled = !affected.length; open.addEventListener('click', () => startReviewQueue(affected.map(b => b.key), g.decision, id(g.group))); card.append(open); root.append(card);
  }
  const checks = $('#review-checks'); checks.replaceChildren();
  const categories = [['placement', 'KML / sheet placement', 'Distances over 75 m are flagged for review, not automatically corrected. Missing positions remain visible.'], ['links', 'Permanent identity links', 'Name and distance matches are candidates only. Confirm with kmlPlacemarkId in Beacons or recordKey in KML ExtendedData.'], ['identity', 'Beacon numbers & duplicate identities', 'Resolve reused or missing numbers before programming hardware or publishing.'], ['locations', 'Location assignments', 'Define location codes once, then apply that mapping to the affected rows.'], ['app', 'Master vs app changes', 'Compare current text and positions with the master. Rounding-only coordinates are listed separately below.'], ['new', 'Planned / unmatched app records', 'A new point may belong to a location without any trail stops.'], ['retired', 'Retirements', 'KML presence does not override App Inclusion.'], ['content', 'Text & inclusion checks', 'Fill missing text and use Active, Draft or Retired independently of hardware status.'], ['hardware', 'Hardware status', 'Use Working, Needs reprogrammed, Missing, Broken or To be purchased.']];
  for (const [code, title, explanation] of categories) {
    const entries = state.entries.filter(e => e.issues.some(i => i.code === code));
    const group = el('details', undefined, 'check-group'); group.open = code === 'placement'; group.append(el('summary', `${title} — ${entries.length} points`), el('p', explanation));
    if (entries.length) { const wrap = el('div', undefined, 'table-scroll'); wrap.append(table(['Point', 'Record', 'What to check'], entries.map(e => [{ label: e.b?.name || e.p?.name, uid: e.uid }, e.b?.key || 'KML only', e.issues.filter(i => i.code === code).map(i => i.text).join('\n')]), true)); group.append(wrap); } else group.append(el('p', 'No issues found in the loaded records.'));
    checks.append(group);
  }
  const rounding = state.entries.filter(e => e.coordinateChange?.kind === 'Consistent with rounding');
  const d = el('details', undefined, 'check-group'); d.append(el('summary', `Coordinates consistent with rounding — ${rounding.length} points`), el('p', 'Both app coordinates round to the written source precision. These are informational, not an automatic reason to move a point. This check is separate from KML placement differences.'));
  d.append(table(['Point', 'Minor', 'App → sheet gap'], rounding.map(e => [{ label: e.b.name, uid: e.uid }, e.b.minor, `${e.coordinateChange.distance.toFixed(1)} m`]), true)); checks.append(d);
  const problems = stopIssues(state.master), s = el('details', undefined, 'check-group'); s.append(el('summary', `Trail-stop references — ${problems.length} issues`));
  const ul = el('ul'); problems.forEach(p => ul.append(el('li', p))); s.append(ul); if (!problems.length) s.append(el('p', 'Loaded stop references have unique valid IDs and orders. Route geometry-to-tour mapping still needs review.')); checks.append(s);
}
function renderTables() {
  const select = $('#table-select'), old = select.value;
  const tabs = Object.keys(state.master.tables).filter(k => k !== 'Trail Coordinates');
  select.replaceChildren(...tabs.map(t => { const o = el('option', t); o.value = t; return o; }));
  select.value = tabs.includes(old) ? old : 'Beacons'; showTable();
}
function showTable() {
  const name = $('#table-select').value, rows = state.master.tables[name] ?? [];
  $('#source-table').replaceChildren();
  $('#table-note').textContent = `${rows.length} records. Values shown exactly as loaded; displayed hardware labels on the map may be normalized.`;
  if (name === 'Trail Stops' && state.master.legacy) $('#table-note').textContent = `${rows.length} landmark-linked stops extracted from legacy Trail Coordinates. Stop Order is their sequence within each trail. Geometry-only rows are omitted.`;
  if (!rows.length) { $('#source-table').append(el('p', 'This table is empty.', 'empty')); return; }
  const headers = Object.keys(rows[0]); $('#source-table').append(table(headers, rows.map(r => headers.map(h => r[h]))));
}
function renderSources() {
  $('#route-inventory').replaceChildren();
  const d = el('details'); d.append(el('summary', `${state.kml.routes.length} read-only route segments`));
  d.append(table(['Route', 'Trail group ID', 'Location', 'Vertices', 'Geometry'], state.kml.routes.map(r => [r.name, r.trailGroupId || 'Missing', r.location || 'Missing', r.coordinates.length, r.kind === 'outerBoundaryIs' ? 'Polygon boundary' : 'LineString']))); $('#route-inventory').append(d);
}

async function refresh() {
  if (state.busy || state.local) return; state.busy = true; $('#refresh').disabled = true; $('#refresh').textContent = 'Refreshing…';
  state.messages = [];
  try {
    const sheetRequest = state.config.sheetDataUrls
      ? Promise.all(Object.entries(state.config.sheetDataUrls).map(async ([name, url]) => [name, parseCsv(await get(url))])).then(Object.fromEntries)
      : get(state.config.sheetDataUrl, state.config.sheetFormat === 'csv' ? 'text' : 'bytes');
    const results = await Promise.allSettled([
      sheetRequest,
      get(state.config.kmlUrl), get(state.config.appJsonUrl, 'json')
    ]);
    if (results[1].status === 'fulfilled') { try { state.kml = parseKml(results[1].value); } catch (err) { state.messages.push(`KML could not be read: ${err.message}. ${state.kml.points.length ? 'Keeping last loaded geometry.' : 'No KML geometry is available.'}`); } }
    else state.messages.push(`KML refresh failed. ${state.kml.points.length ? 'Keeping last loaded geometry.' : 'No KML geometry is available.'}`);
    if (results[2].status === 'fulfilled' && Array.isArray(results[2].value.landmarks)) state.app = results[2].value;
    else state.messages.push(`Current-app JSON unavailable. ${state.app ? 'Comparisons use its last loaded copy.' : 'App comparisons cannot be completed.'}`);
    try {
      if (results[0].status === 'rejected') throw results[0].reason;
      const parsed = state.config.sheetDataUrls ? { tables: results[0].value, formulaCount: 0 } : state.config.sheetFormat === 'csv' ? { tables: { ...state.fallback, Beacons: parseCsv(results[0].value) }, formulaCount: 0 } : readWorkbook(results[0].value);
      const master = normalize(parsed.tables); // Validate before replacing last good data.
      state.master = master; state.lastGood = new Date().toISOString(); state.mode = state.config.sheetDataUrls ? 'Live published Google Sheet' : state.config.sheetFormat === 'csv' ? 'Live Beacons CSV + supporting snapshots' : 'Live Drive workbook';
      if (state.config.sheetFormat === 'csv') state.messages.push(`Only Beacons is live. Locations, trails, stops and grouped decisions use the fallback captured ${date(state.snapshot?.capturedAt)}.`);
      if (parsed.formulaCount) state.messages.push(`${parsed.formulaCount} formula cells use saved results from the workbook. Formulas are not recalculated by this page.`);
    } catch (err) {
      const hadLive = state.mode.startsWith('Live') || state.mode.startsWith('Stale');
      if (!state.master && state.fallback) { state.master = normalize(state.fallback); state.lastGood = state.snapshot.capturedAt; }
      state.mode = hadLive ? 'Stale — last successful workbook' : 'CSV fallback — not live';
      state.messages.push(`Linked source could not be refreshed (${err.message || 'network or sharing error'}). ${hadLive ? 'Keeping the last successful values.' : 'Showing the saved CSV snapshot.'} Check the shared file or try Refresh now.`);
    }
    rebuild();
  } catch (err) { notice(`Could not load preview: ${err.message}`); }
  finally { state.busy = false; $('#refresh').disabled = false; $('#refresh').textContent = 'Refresh now'; }
}
async function startup() {
  state.config = await get('config.json', 'json');
  for (const [selector, url] of [['#edit-sheet', state.config.sheetEditUrl], ['#source-file', state.config.sheetPublicUrl ?? state.config.sheetEditUrl], ['#download-kml', state.config.kmlUrl], ['#edit-earth', state.config.earthEditUrl], ['#app-json', state.config.appJsonUrl]]) link(selector, url);
  if (state.config.sheetEditLabel) $('#edit-sheet').textContent = state.config.sheetEditLabel;
  if (state.config.earthEditUrl !== 'https://earth.google.com/web/') $('#earth-note').textContent = 'Open the linked Google Earth project to edit geography. Export changes and replace the served KML; this preview does not save Earth edits automatically.';
  try {
    state.snapshot = await get(state.config.fallbackManifest, 'json'); const base = new URL(state.config.fallbackManifest, location.href);
    const entries = await Promise.all(Object.entries(state.snapshot.files).map(async ([name, filename]) => [name, parseCsv(await get(new URL(filename, base)))]));
    state.fallback = Object.fromEntries(entries); normalize(state.fallback);
    $('#snapshot-description').textContent = `CSV fallback captured ${date(state.snapshot.capturedAt)}. Download these tables if the linked file is unavailable.`;
    for (const [name, filename] of Object.entries(state.snapshot.files)) { const a = el('a', `${name} CSV`); a.href = new URL(filename, base).href; a.download = filename; $('#csv-downloads').append(a); }
  } catch (err) { state.messages.push(`Fallback snapshot unavailable: ${err.message}`); }
  initMap(); await refresh();
  setInterval(() => { if ($('#auto-refresh').checked && !document.hidden && !state.local) refresh(); }, Math.max(30, Number(state.config.refreshSeconds) || 60) * 1000);
}
document.querySelectorAll('[data-view]').forEach(b => b.addEventListener('click', () => switchView(b.dataset.view)));
for (const selector of ['#search', '#location', '#hardware', '#scope']) $(selector).addEventListener('input', () => { renderPoints(); fitMap(); });
$('#diff-search').addEventListener('input', renderAppDiff);
$('#clear-filters').addEventListener('click', () => clearFilters());
$('#clear-review-filter').addEventListener('click', () => clearFilters());
$('#refresh').addEventListener('click', refresh); $('#fit-map').addEventListener('click', fitMap); $('#show-app').addEventListener('change', drawRoutes);
$('#table-select').addEventListener('change', showTable); $('#print').addEventListener('click', () => { $('#review-checks').querySelectorAll('details').forEach(d => d.open = true); window.print(); });
$('#local-file').addEventListener('change', async event => {
  const file = event.target.files[0]; if (!file) return; $('#local-error').textContent = '';
  try {
    if (state.busy) throw Error('Wait for the current refresh to finish, then choose the file again.');
    if (file.size > 8 * 1024 * 1024) throw Error('File exceeds the 8 MB preview limit.');
    const csv = file.name.toLowerCase().endsWith('.csv');
    const parsed = csv ? { tables: { ...(state.fallback ?? {}), Beacons: parseCsv(await file.text()) } } : readWorkbook(await file.arrayBuffer());
    const master = normalize(parsed.tables); state.local = true; state.master = master; state.mode = `Local file: ${file.name}`; state.lastGood = new Date().toISOString(); state.messages = ['Local preview only. This file has not been uploaded or saved to the site. Live refresh is paused.'];
    if (csv) state.messages.push('Only Beacons comes from your local CSV. Supporting tables use the saved site snapshot.');
    if (parsed.formulaCount) state.messages.push(`${parsed.formulaCount} formula cells use saved values, not recalculated results.`);
    $('#auto-refresh').checked = false; $('#auto-refresh').disabled = true; $('#refresh').disabled = true; state.selected = null; rebuild();
  } catch (err) { $('#local-error').textContent = `File not loaded: ${err.message}. Previous preview is unchanged.`; }
  event.target.value = '';
});
$('#restore-live').addEventListener('click', () => { state.local = false; state.master = null; state.mode = 'Loading'; $('#auto-refresh').disabled = false; $('#auto-refresh').checked = true; refresh(); });
startup().catch(err => { $('#source-mode').textContent = 'Preview unavailable'; notice(`Setup failed: ${err.message}. Check that this page is served over HTTP and config.json is available.`); });
