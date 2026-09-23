import { unzipSync, strFromU8 } from './vendor/fflate.mjs';

export const clean = v => String(v ?? '').trim();
export const id = v => /^\d+(\.0+)?$/.test(clean(v)) ? String(Number(v)) : clean(v);
const compact = v => clean(v).replace(/\s+/g, ' ');
export const number = v => clean(v) !== '' && Number.isFinite(Number(v)) ? Number(v) : null;
export function position(lat, lon) {
  lat = number(lat); lon = number(lon);
  return lat !== null && lon !== null && Math.abs(lat) <= 90 && Math.abs(lon) <= 180 ? [lat, lon] : null;
}
export function metres(a, b) {
  if (!a || !b) return null;
  const r = Math.PI / 180, dlat = (b[0] - a[0]) * r, dlon = (b[1] - a[1]) * r;
  return 12742000 * Math.asin(Math.min(1, Math.sqrt(Math.sin(dlat / 2) ** 2 + Math.cos(a[0] * r) * Math.cos(b[0] * r) * Math.sin(dlon / 2) ** 2)));
}
export function csvRows(text) {
  if (/^\s*</.test(text)) throw Error('Received an HTML page instead of CSV. Check sharing/export settings.');
  text = text.replace(/^\uFEFF/, '');
  const rows = []; let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (quoted && text[i + 1] === '"') { field += '"'; i++; }
      else if (quoted || field === '') quoted = !quoted;
      else throw Error('Invalid quote in CSV.');
    } else if (c === ',' && !quoted) { row.push(field); field = ''; }
    else if ((c === '\n' || c === '\r') && !quoted) {
      row.push(field); if (row.some(v => v !== '')) rows.push(row);
      row = []; field = ''; if (c === '\r' && text[i + 1] === '\n') i++;
    } else field += c;
  }
  if (quoted) throw Error('CSV has an unclosed quoted field.');
  row.push(field); if (row.some(v => v !== '')) rows.push(row);
  return rows;
}
export function records(rows) {
  if (!rows.length) throw Error('No table rows found.');
  const headers = rows[0].map(clean);
  if (new Set(headers).size !== headers.length || headers.some(h => !h)) throw Error('Blank or duplicate table headers.');
  return rows.slice(1).filter(row => row.some(v => clean(v))).map((values, index) => {
    if (values.length > headers.length) throw Error(`Too many cells on row ${index + 2}.`);
    return Object.fromEntries(headers.map((h, i) => [h, values[i] ?? '']));
  });
}
export const parseCsv = text => records(csvRows(text));
const nodes = (element, name) => Array.from(element.getElementsByTagNameNS('*', name));
const children = (element, name) => Array.from(element.children ?? element.childNodes).filter(n => n.nodeType === 1 && n.localName === name);
const child = (element, name) => children(element, name)[0];
const value = (element, name) => child(element, name)?.textContent ?? '';
function xml(text) {
  if (/<!DOCTYPE|<!ENTITY/i.test(text)) throw Error('DTD/entity declarations are not supported.');
  const doc = new DOMParser().parseFromString(text, 'application/xml');
  if (nodes(doc, 'parsererror').length) throw Error('Invalid XML file.');
  return doc;
}

/** OOXML values only: no macros, formulas, external links, or embedded code run. */
export function readWorkbook(bytes) {
  if (bytes.byteLength > 8 * 1024 * 1024) throw Error('Workbook is larger than the 8 MB preview limit.');
  let total = 0;
  const files = unzipSync(new Uint8Array(bytes), { filter: file => {
    const keep = /^(xl\/(workbook\.xml|_rels\/workbook\.xml\.rels|sharedStrings\.xml|worksheets\/sheet\d+\.xml))$/.test(file.name);
    if (keep) { total += file.originalSize; if (total > 24 * 1024 * 1024) throw Error('Expanded workbook exceeds the preview limit.'); }
    return keep;
  }});
  const read = path => { if (!files[path]) throw Error(`Workbook part missing: ${path}`); return xml(strFromU8(files[path])); };
  const strings = files['xl/sharedStrings.xml'] ? nodes(read('xl/sharedStrings.xml'), 'si').map(si => nodes(si, 't').map(t => t.textContent).join('')) : [];
  const rels = new Map(nodes(read('xl/_rels/workbook.xml.rels'), 'Relationship').filter(r => r.getAttribute('TargetMode') !== 'External').map(r => [r.getAttribute('Id'), r.getAttribute('Target')]));
  const tables = {}; let formulaCount = 0;
  const wanted = new Set(['Guide', 'Beacons', 'Locations', 'Trails', 'Stop Content', 'Decisions', 'Trail Stops', 'Trail Coordinates', 'Needs Review', 'Review Details']);
  for (const sheet of nodes(read('xl/workbook.xml'), 'sheet')) {
    const name = sheet.getAttribute('name'); if (!wanted.has(name)) continue;
    const target = rels.get(sheet.getAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships', 'id'));
    if (!target) throw Error('Missing worksheet relationship.');
    const path = target.startsWith('/') ? target.slice(1) : `xl/${target.replace(/^\.\//, '')}`;
    const rows = [];
    for (const row of nodes(read(path), 'row')) {
      const cells = [];
      for (const cell of children(row, 'c')) {
        const letters = (cell.getAttribute('r') ?? '').match(/^[A-Z]+/)?.[0];
        if (!letters) throw Error('Invalid workbook cell address.');
        let col = 0; for (const letter of letters) col = col * 26 + letter.charCodeAt(0) - 64;
        if (col > 256) throw Error('Preview supports up to 256 columns.');
        const type = cell.getAttribute('t'), raw = value(cell, 'v');
        if (child(cell, 'f')) formulaCount++;
        cells[col - 1] = type === 's' ? strings[Number(raw)] ?? '' : type === 'inlineStr' ? nodes(cell, 't').map(t => t.textContent).join('') : type === 'b' ? (raw === '1' ? 'true' : 'false') : raw;
      }
      if (cells.some(c => clean(c))) rows.push(Array.from(cells, c => c ?? ''));
      if (rows.length > 5000) throw Error('Preview supports up to 5,000 rows per tab.');
    }
    if (rows.length) tables[name] = records(rows);
  }
  return { tables, formulaCount };
}

export function parseKml(text) {
  const doc = xml(text); const points = [], routes = [], warnings = [];
  for (const p of nodes(doc, 'Placemark')) {
    const name = value(p, 'name'), kmlId = p.getAttribute('id') ?? '', data = {};
    for (const d of nodes(p, 'Data')) data[d.getAttribute('name')] = value(d, 'value');
    for (const d of nodes(p, 'SimpleData')) data[d.getAttribute('name')] = d.textContent;
    const coords = geometry => {
      const raw = nodes(geometry, 'coordinates')[0]?.textContent ?? '';
      const result = raw.trim().split(/\s+/).filter(Boolean).map(tuple => { const v = tuple.split(','); return position(v[1], v[0]); });
      if (!result.length || result.some(v => !v)) throw Error(`Invalid coordinates in KML: ${name || kmlId}`);
      return result;
    };
    for (const geometry of nodes(p, 'Point')) points.push({ kmlId, name, position: coords(geometry)[0], data });
    for (const geometry of [...nodes(p, 'LineString'), ...nodes(p, 'outerBoundaryIs')]) {
      const coordinates = coords(geometry);
      if (coordinates.length < 2) throw Error(`Route has fewer than two vertices: ${name}`);
      routes.push({ kmlId, name, coordinates, kind: geometry.localName, location: clean(data.location), trailGroupId: clean(data.trailGroupId) });
    }
  }
  if (!routes.length && !points.length) throw Error('KML has no usable points or routes.');
  if (new Set(points.map(p => p.kmlId)).size !== points.length || points.some(p => !p.kmlId)) warnings.push('Some KML points have missing or duplicate IDs. These cannot be confirmed links.');
  return { points, routes, warnings };
}

const aliases = { 'kids mt': 'kids mountain', 'small mt': 'small mountain', 'rope ladder': 'climbing ladder', '3 small green slides': 'small slides', '2 main blue slides': 'large slides', 'gently sloping trail': 'kids mountain trail', 'welcome to park': 'park entrance', 'pavillion': 'pavilion', 'rain barrel': 'rain barrels', 'native plant mgt area': 'native plant management area', 'native plant management': 'native plant management area', 'bluebird and cavity nesting birds': 'bluebird and cavity nesting bird program', 'native vs invasives plants': 'native plant vs invasive plants', 'water fowl': 'waterfowl', 'nike missle': 'nike missile' };
const nameKey = name => { const n = clean(name).toLowerCase().replace(/[^a-z0-9 ]/g, '').trim(); return aliases[n] ?? n; };
export const statusOptions = ['Working', 'Needs reprogrammed', 'Missing', 'Broken', 'To be purchased'];
function hardware(raw) {
  const s = clean(raw).toLowerCase();
  if (s.includes('reprogram')) return 'Needs reprogrammed';
  if (s.includes('broken')) return 'Broken';
  if (s.includes('missing') || s.includes("can't locate")) return 'Missing';
  if (s === 'working') return 'Working';
  if (s === 'needs beacon' || s === 'to be purchased') return 'To be purchased';
  return clean(raw) === 'DELETE' ? '' : clean(raw);
}
export function normalize(tables) {
  if (!Array.isArray(tables.Beacons) || !tables.Beacons.length) throw Error('The source needs a nonempty Beacons tab.');
  const first = tables.Beacons[0];
  if (!('name' in first) || !('recordKey' in first) || (!('id' in first) && !('Minor' in first))) throw Error('Beacons needs recordKey, name and Minor (or id) columns.');
  const beacons = tables.Beacons.map((raw, index) => {
    const sourceStatus = raw.Status ?? raw.beaconStatus ?? '';
    return { ...raw, key: clean(raw.recordKey), row: index + 2, minor: id(raw.Minor ?? raw.id),
      sourceMinor: id(raw['Source Minor'] ?? raw.sourceId), sourceMajor: id(raw['Source Major'] ?? raw.sourceMajor),
      name: clean(raw.name), location: clean(raw.location), status: hardware(sourceStatus), sourceStatus,
      inclusion: clean(raw['App Inclusion'] ?? raw.appStatus), position: position(raw.latitude, raw.longitude),
      kmlId: clean(raw.kmlPlacemarkId ?? raw['KML Placemark ID']), raw };
  });
  const locations = (tables.Locations ?? []).map(r => ({ ...r, major: id(r.Major ?? r.beaconMajorCode) }));
  const trails = (tables.Trails ?? []).map(r => ({ ...r, id: id(r.id) }));
  const contentOnly = !!tables['Stop Content'];
  const legacy = !contentOnly && !tables['Trail Stops'] && !!tables['Trail Coordinates'];
  const orders = new Map();
  const stops = (tables['Stop Content'] ?? tables['Trail Stops'] ?? tables['Trail Coordinates'] ?? []).filter(r => contentOnly ? clean(r['KML recordKey'] ?? r.recordKey) : clean(r['Beacon Minor'] ?? r.landmarkId)).map(r => {
    const trailId = id(r['Trail ID'] ?? r.trailId); orders.set(trailId, (orders.get(trailId) ?? 0) + 1);
    return { trailId, recordKey: clean(r['KML recordKey'] ?? r.recordKey), minor: id(r['Beacon Minor'] ?? r.landmarkId), order: contentOnly ? null : legacy ? orders.get(trailId) : number(r['Stop Order'] ?? r.stopOrder),
      forward: r['Forward Instructions'] ?? r.forwardInstructions ?? r.distanceToNextClockwiseDescription ?? '',
      reverse: r['Reverse Instructions'] ?? r.reverseInstructions ?? r.distanceToNextCounterClockwiseDescription ?? '',
      forwardDistance: r['Forward Distance'] ?? r.forwardDistance ?? r.distanceToNextClockwise ?? '',
      reverseDistance: r['Reverse Distance'] ?? r.reverseDistance ?? r.distanceToNextCounterClockwise ?? '' };
  });
  const displayedTables = legacy ? { ...tables, 'Trail Stops': stops.map(s => ({ 'Trail ID': s.trailId, 'Stop Order': String(s.order), 'Beacon Minor': s.minor, 'Forward Distance': s.forwardDistance, 'Forward Instructions': s.forward, 'Reverse Distance': s.reverseDistance, 'Reverse Instructions': s.reverse })) } : tables;
  return { beacons, locations, trails, stops, groups: tables['Needs Review'] ?? [], tables: displayedTables, legacy, contentOnly };
}

export function coordinateChange(beacon, app) {
  const before = position(app?.coordinates?.latitude, app?.coordinates?.longitude), after = beacon.position;
  if (!before || !after) return { kind: 'Unavailable', distance: null };
  const distance = metres(before, after);
  if (distance < 0.001) return { kind: 'Same coordinates', distance };
  const source = clean(beacon.sourceCoordinates).split(',').map(clean);
  const written = source.length === 2 && source.every((v, i) => number(v) !== null && Math.abs(Number(v) - after[i]) < 1e-10) ? source : [beacon.latitude, beacon.longitude];
  const rounding = written.every((v, i) => {
    const text = clean(v); if (!/^-?\d+(\.\d+)?$/.test(text)) return false;
    const digits = (text.split('.')[1] ?? '').length;
    return digits <= 12 && Math.abs(Number(before[i].toFixed(digits)) - after[i]) < 1e-10;
  });
  return { kind: rounding ? 'Consistent with rounding' : 'Changed beyond rounding', distance };
}

/** Explicit IDs confirm links. Names and proximity only suggest candidates. */
export function reconcile(master, kml, app) {
  const bs = master.beacons;
  const counts = values => { const m = new Map(); for (const v of values) m.set(v, (m.get(v) ?? 0) + 1); return m; };
  const keyCounts = counts(bs.map(b => b.key)), kmlCounts = counts(kml.points.map(p => p.kmlId));
  const proposed = kml.points.map(p => {
    const key = clean(p.data.recordKey), explicit = bs.filter(b => (p.kmlId && b.kmlId === p.kmlId) || (key && b.key === key));
    if (explicit.length || key) {
      const b = explicit[0];
      if (explicit.length !== 1 || !p.kmlId || kmlCounts.get(p.kmlId) !== 1 || !b?.key || keyCounts.get(b.key) !== 1 || (key && key !== b.key) || (b.kmlId && b.kmlId !== p.kmlId)) return { p, state: 'conflict', reason: 'Conflicting or missing explicit identity link' };
      return { p, b, state: 'confirmed', reason: 'Linked by permanent ID' };
    }
    let candidates = bs.filter(b => !b.kmlId && nameKey(b.name) === nameKey(p.name));
    candidates.sort((a, b) => (metres(a.position, p.position) ?? Infinity) - (metres(b.position, p.position) ?? Infinity));
    const near = bs.filter(b => !b.kmlId && b.position && metres(b.position, p.position) <= 3);
    if ((!candidates.length || (metres(candidates[0].position, p.position) ?? Infinity) > 75) && near.length === 1) candidates = near;
    if (!candidates.length) return { p, state: 'unlinked', reason: 'No sheet candidate' };
    const b = candidates[0], d = metres(b.position, p.position), second = candidates[1];
    if (second && (d === null || (second.position && Math.abs(metres(second.position, p.position) - d) < 25))) return { p, state: 'conflict', reason: 'Repeated name: choose a permanent link' };
    if (!b.key || keyCounts.get(b.key) !== 1) return { p, state: 'conflict', reason: 'Sheet record ID is missing or duplicated' };
    return { p, b, state: 'candidate', reason: d !== null && d <= 3 && nameKey(b.name) !== nameKey(p.name) ? 'Near-identical position; different name' : 'Name / alias and proximity candidate' };
  });
  const claims = counts(proposed.filter(r => r.b).map(r => r.b.key));
  for (const r of proposed) if (r.b && claims.get(r.b.key) > 1) { r.b = null; r.state = 'conflict'; r.reason = 'Multiple KML points claim the same sheet record'; }
  const used = new Set(proposed.filter(r => r.b).map(r => r.b.key));
  const entries = proposed.map((r, i) => ({ ...r, uid: `kml-${r.p.kmlId && kmlCounts.get(r.p.kmlId) === 1 ? r.p.kmlId : i}`, position: r.p.position }));
  bs.forEach((b, i) => { if (!used.has(b.key) || keyCounts.get(b.key) > 1) entries.push({ b, uid: `sheet-${b.key && keyCounts.get(b.key) === 1 ? b.key : i}`, state: b.kmlId ? 'conflict' : 'unlinked', reason: b.kmlId ? 'KML ID not uniquely resolved' : 'Sheet only; no KML link', position: b.position }); });
  const issue = (code, text) => ({ code, text });
  for (const e of entries) {
    const b = e.b; e.issues = []; e.stops = []; e.changes = [];
    e.gap = b && e.p ? metres(b.position, e.p.position) : null;
    if (e.state !== 'confirmed') e.issues.push(issue('links', e.reason));
    if (e.gap !== null && e.gap > 75) e.issues.push(issue('placement', `KML and sheet positions differ by ${Math.round(e.gap).toLocaleString()} m`));
    if (!b) continue;
    if (!b.key || keyCounts.get(b.key) !== 1) e.issues.push(issue('identity', 'Missing or duplicate recordKey'));
    const minorMatches = bs.filter(other => b.minor && other.minor === b.minor);
    if (!/^\d+$/.test(b.minor) || Number(b.minor) < 1 || Number(b.minor) > 65535 || minorMatches.length !== 1) e.issues.push(issue('identity', 'Minor is missing, invalid or duplicated'));
    if (b.sourceMinor && b.minor && b.sourceMinor !== b.minor) e.issues.push(issue('identity', `Source Minor ${b.sourceMinor} differs from app Minor ${b.minor}`));
    const location = master.locations.find(l => l.id === b.location); e.location = location;
    if (!location) e.issues.push(issue('locations', 'Location has not been mapped'));
    if (location && b.sourceMajor && b.sourceMajor !== location.major) e.issues.push(issue('identity', `Source Major ${b.sourceMajor} differs from location Major ${location.major}`));
    if (!b.status || !statusOptions.includes(b.status)) e.issues.push(issue('hardware', 'Hardware status needs review'));
    if (!['Active', 'Draft', 'Retired'].includes(b.inclusion)) e.issues.push(issue('content', 'App Inclusion must be Active, Draft or Retired'));
    if (!b.position && !e.p) e.issues.push(issue('placement', 'No usable coordinates yet'));
    if (b.inclusion === 'Retired') e.issues.push(issue('retired', e.p ? 'Retired in sheet, still present in KML' : 'Retirement proposed'));
    if (b.inclusion === 'Draft') e.issues.push(issue('new', 'Draft / planned point'));
    if (!compact(b.description) || !compact(b.longDescription) || /\bTBA\b/i.test(`${b.description} ${b.longDescription}`)) e.issues.push(issue('content', 'Missing or placeholder app text'));
    const matches = (app?.landmarks ?? []).filter(a => id(a.id) === b.minor && a.location === b.location);
    e.app = matches.length === 1 ? matches[0] : null;
    if (app && !e.app) e.issues.push(issue('new', 'No unique current-app match by location and Minor'));
    if (e.app) {
      for (const field of ['name', 'description', 'longDescription', 'imagePath', 'imageAlt', 'category']) if (compact(e.app[field]) !== compact(b[field])) e.changes.push({ field, before: e.app[field] ?? '', after: b[field] ?? '' });
      e.coordinateChange = coordinateChange(b, e.app);
      if (e.coordinateChange.kind === 'Changed beyond rounding') e.issues.push(issue('app', 'Sheet coordinates changed beyond rounding versus app'));
      if (e.changes.length) e.issues.push(issue('app', `${e.changes.length} text / image / category fields differ from app`));
    }
    e.stops = master.stops.filter(s => s.recordKey ? s.recordKey === b.key : s.minor === b.minor).map(s => ({ ...s,
      order: s.order ?? (e.p?.data.trailId === s.trailId ? number(e.p.data.stopOrder) : null)
    })).sort((a, z) => a.trailId.localeCompare(z.trailId) || (a.order ?? 0) - (z.order ?? 0));
  }
  return entries;
}

export function stopIssues(master) {
  const seen = new Set(); const issues = [];
  for (const s of master.stops) {
    const key = `${s.trailId}:${s.order}`;
    const bs = master.beacons.filter(b => s.recordKey ? b.key === s.recordKey : b.minor === s.minor);
    if (!master.trails.some(t => t.id === s.trailId)) issues.push(`Stop ${key}: trail does not exist.`);
    if (!master.contentOnly && (!Number.isInteger(s.order) || s.order < 1 || seen.has(key))) issues.push(`Stop ${key}: invalid or duplicate order.`);
    if (bs.length !== 1) issues.push(`Stop ${key}: ${s.recordKey ? `recordKey ${s.recordKey}` : `Minor ${s.minor}`} is missing or ambiguous.`);
    else {
      if (bs[0].inclusion !== 'Active') issues.push(`Stop ${key}: ${bs[0].name} is ${bs[0].inclusion || 'missing App Inclusion'}.`);
      const trail = master.trails.find(t => t.id === s.trailId);
      if (trail && trail.location !== bs[0].location) issues.push(`Stop ${key}: ${bs[0].name} and its trail have different location assignments; confirm this is intentional.`);
    }
    seen.add(key);
  }
  return issues;
}
