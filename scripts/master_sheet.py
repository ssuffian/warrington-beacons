"""Validate the master workbook with KML and generate the app's atomic JSON."""
import argparse, csv, difflib, json, math, re, uuid, zipfile
from pathlib import Path
from urllib.parse import unquote, urlparse
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
XNS = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
KNS = {'k': 'http://www.opengis.net/kml/2.2'}
IMAGE_ORIGIN = 'https://trails.warringtoneac.org'


def normalize_image_path(value):
    """Return a server-relative path while accepting clickable hosted URLs."""
    value = str(value or '').strip()
    parsed = urlparse(value)
    if parsed.scheme or parsed.netloc:
        if parsed.scheme != 'https' or parsed.netloc.lower() != urlparse(IMAGE_ORIGIN).netloc:
            raise ValueError('Image URL must be hosted at '+IMAGE_ORIGIN)
        if parsed.query or parsed.fragment:
            raise ValueError('Image URL cannot contain a query or fragment')
        value = unquote(parsed.path).lstrip('/')
    return value


def read_xlsx(path, allow_cached_formulas=False):
    with zipfile.ZipFile(path) as z:
        strings = []
        if 'xl/sharedStrings.xml' in z.namelist():
            strings = [''.join(t.text or '' for t in si.iter(XNS+'t')) for si in ET.fromstring(z.read('xl/sharedStrings.xml'))]
        rels = {x.attrib['Id']: x.attrib['Target'] for x in ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))}
        result = {}
        for sh in ET.fromstring(z.read('xl/workbook.xml')).find(XNS+'sheets'):
            target = rels[sh.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']]
            target = target.lstrip('/') if target.startswith('/') else 'xl/'+target
            rows = []
            for row in ET.fromstring(z.read(target)).findall('.//'+XNS+'sheetData/'+XNS+'row'):
                cells = {}
                for c in row:
                    letters = re.match('[A-Z]+', c.attrib['r'])[0]; col = 0
                    for letter in letters: col = col*26+ord(letter)-64
                    v = c.find(XNS+'v'); value = v.text if v is not None else ''
                    if c.attrib.get('t') == 's': value = strings[int(value)]
                    elif c.attrib.get('t') == 'inlineStr': value = ''.join(t.text or '' for t in c.iter(XNS+'t'))
                    elif c.attrib.get('t') == 'b': value = 'true' if value == '1' else 'false'
                    if c.find(XNS+'f') is not None and not allow_cached_formulas:
                        raise ValueError('Formulas are not allowed: '+sh.attrib['name']+'!'+c.attrib['r'])
                    cells[col-1] = value or ''
                if any(cells.values()): rows.append([cells.get(i, '') for i in range(max(cells)+1)])
            result[sh.attrib['name']] = rows
        return result


def tables(path):
    aliases = {
        'Beacons': {'Minor': 'id', 'Source Minor': 'sourceId', 'Source Major': 'sourceMajor', 'App Inclusion': 'appStatus',
                    'Trail ID': 'trailId', 'Stop Order': 'stopOrder'},
        'Locations': {'Major': 'beaconMajorCode', 'iBeacon UUID': 'iBeaconUUID', 'AltBeacon UUID': 'altBeaconUUID'},
        'Trails': {'Trail ID': 'id', 'Start recordKey': 'startRecordKey', 'End recordKey': 'endRecordKey'},
        'Stop Content': {'Trail ID': 'trailId', 'KML recordKey': 'recordKey', 'Stop Order': 'stopOrder',
                         'Forward Distance': 'forwardDistance', 'Forward Instructions': 'forwardInstructions',
                         'Reverse Distance': 'reverseDistance', 'Reverse Instructions': 'reverseInstructions'},
        'Trail Stops': {'Trail ID': 'trailId', 'Stop Order': 'stopOrder', 'Beacon Minor': 'landmarkId',
                        'Forward Distance': 'forwardDistance', 'Forward Instructions': 'forwardInstructions',
                        'Reverse Distance': 'reverseDistance', 'Reverse Instructions': 'reverseInstructions'},
    }
    if Path(path).is_dir():
        raw = {}
        for file in Path(path).glob('*.csv'):
            with file.open(newline='', encoding='utf-8-sig') as handle:
                raw[file.stem] = list(csv.reader(handle))
    else:
        raw = read_xlsx(path)
    result = {}
    for name, rows in raw.items():
        if not rows: continue
        headers = [aliases.get(name, {}).get(h, h) for h in rows[0]]
        if len(headers) != len(set(headers)): raise ValueError('Duplicate headers: '+name)
        result[name] = [dict(zip(headers, values+['']*len(headers))) for values in rows[1:]]
    return result


def _data(pm):
    return {d.get('name'): d.findtext('k:value', '', KNS) for d in pm.findall('k:ExtendedData/k:Data', KNS)}


def _coords(text):
    result = []
    for token in (text or '').split():
        lon, lat, *_ = token.split(','); result.append((float(lat), float(lon)))
    return result


def canonical_trail_id(value):
    """Normalize editor-entered trail IDs to stable lowercase URL-safe IDs."""
    return re.sub(r'-+', '-', re.sub(r'[^a-z0-9]+', '-', str(value or '').strip().lower())).strip('-')


def read_kml(path, api_version='v1'):
    root = ET.parse(path).getroot(); points, routes, errors = {}, {}, []
    for pm in root.findall('.//k:Placemark', KNS):
        meta = _data(pm); point = pm.find('k:Point', KNS)
        if point is not None:
            key = meta.get('recordKey', '').strip(); coordinates = _coords(point.findtext('k:coordinates', '', KNS))
            if not key: errors.append(('KML Point', 'Missing recordKey'))
            elif key in points: errors.append((key, 'Duplicate KML Point recordKey'))
            elif len(coordinates) != 1: errors.append((key, 'Point must have exactly one coordinate'))
            else: points[key] = {'coordinate': coordinates[0], 'trailId': meta.get('trailId', '').strip(), 'stopOrder': meta.get('stopOrder', '').strip()}
            continue
        string_ids = api_version in ('v2', 'v3')
        group = (meta.get('trailId', '') if string_ids else meta.get('trailGroupId', '')).strip()
        if string_ids: group = canonical_trail_id(group)
        if not group: continue
        parts = [_coords(n.text) for n in pm.findall('.//k:LineString/k:coordinates', KNS)]
        parts += [_coords(n.text) for n in pm.findall('.//k:Polygon/k:outerBoundaryIs/k:LinearRing/k:coordinates', KNS)]
        routes.setdefault(group, []).extend(p for p in parts if len(p) >= 2)
    return points, routes, errors


def _distance(a, b): return math.hypot(a[0]-b[0], a[1]-b[1])


def _merge(parts):
    remaining = [list(p) for p in parts]; path = remaining.pop(0)
    while remaining:
        choices = []
        for i, part in enumerate(remaining):
            choices += [(_distance(path[-1], part[0]), i, False, False), (_distance(path[-1], part[-1]), i, True, False),
                        (_distance(path[0], part[-1]), i, False, True), (_distance(path[0], part[0]), i, True, True)]
        _, i, reverse, prepend = min(choices); part = remaining.pop(i)
        if reverse: part.reverse()
        path = part + path if prepend else path + part
    return path


def _metrics(path):
    out = [0.0]
    for a, b in zip(path, path[1:]): out.append(out[-1]+_distance(a, b))
    return out


def _project(path, cumulative, point):
    best = (float('inf'), 0.0)
    for i, (a, b) in enumerate(zip(path, path[1:])):
        dy, dx = b[0]-a[0], b[1]-a[1]; denom = dx*dx+dy*dy
        t = 0 if denom == 0 else max(0, min(1, ((point[0]-a[0])*dy+(point[1]-a[1])*dx)/denom))
        q = (a[0]+t*dy, a[1]+t*dx); along = cumulative[i]+t*(cumulative[i+1]-cumulative[i])
        best = min(best, (_distance(point, q), along))
    return best[1]


def route_with_stops(parts, stops):
    path = _merge(parts); closed = _distance(path[0], path[-1]) < 1e-10
    cumulative = _metrics(path); total = cumulative[-1]
    positions = [_project(path, cumulative, s['coordinate']) for s in stops]

    def plain(point): return {'latitude': point[0], 'longitude': point[1]}
    def stop_value(stop):
        if stop.get('endpoint'): return plain(stop['coordinate'])
        value = {'latitude': stop['coordinate'][0], 'longitude': stop['coordinate'][1], 'landmarkId': stop['landmarkId']}
        value.update(stop['content']); return value
    def between(a, b):
        if not closed:
            selected = [(d, p) for d, p in zip(cumulative, path) if min(a, b) < d < max(a, b)]
            if b < a: selected.reverse()
            return [plain(p) for _, p in selected]
        forward = (b-a) % total; backward = (a-b) % total
        if forward <= backward:
            selected = sorted((((d-a) % total, p) for d, p in zip(cumulative[:-1], path[:-1]) if 0 < (d-a) % total < forward))
        else:
            selected = sorted((((a-d) % total, p) for d, p in zip(cumulative[:-1], path[:-1]) if 0 < (a-d) % total < backward))
        return [plain(p) for _, p in selected]

    if len(stops) == 1:
        # A lone anchor cannot orient the route, so keep the KML direction around it.
        pos = positions[0]
        if closed:
            loop = sorted((((d-pos) % total, p) for d, p in zip(cumulative[:-1], path[:-1]) if (d-pos) % total > 0))
            return [stop_value(stops[0])] + [plain(p) for _, p in loop]
        return ([plain(p) for d, p in zip(cumulative, path) if d < pos] + [stop_value(stops[0])]
                + [plain(p) for d, p in zip(cumulative, path) if d > pos])
    result = []
    if not closed and len(positions) > 1:
        # Include the route before the first stop from the end implied by the
        # first leg, while keeping explicit spreadsheet stop order authoritative.
        if positions[1] >= positions[0]: result.extend(plain(p) for d, p in zip(cumulative, path) if d < positions[0])
        else: result.extend(plain(p) for d, p in reversed(list(zip(cumulative, path))) if d > positions[0])
    result.append(stop_value(stops[0]))
    for i in range(len(stops)-1):
        result.extend(between(positions[i], positions[i+1])); result.append(stop_value(stops[i+1]))
    if closed:
        result.extend(between(positions[-1], positions[0]))
    elif len(positions) > 1:
        if positions[-1] >= positions[-2]: result.extend(plain(p) for d, p in zip(cumulative, path) if d > positions[-1])
        else: result.extend(plain(p) for d, p in reversed(list(zip(cumulative, path))) if d < positions[-1])
    return result


def validate(t, kml_path, api_version='v1'):
    errors = []
    def fail(where, issue): errors.append({'record': str(where), 'issue': issue})
    def integer(v, where):
        try: return int(str(v))
        except ValueError: fail(where, 'Invalid integer: '+str(v)); return 0
    def boolean(v, where):
        if str(v).lower() not in ('true', 'false'): fail(where, 'Boolean must be true or false')
        return str(v).lower() == 'true'
    for name in ('Beacons', 'Locations', 'Trails', 'Stop Content'):
        if name not in t: fail(name, 'Required tab missing')
    if errors: return {}, errors
    points, routes, kml_errors = read_kml(kml_path, api_version)
    for where, issue in kml_errors: fail(where, issue)
    locations = []
    for r in t['Locations']:
        where = 'Location '+r.get('id', '')
        if r.get('reviewStatus') != 'Approved': fail(where, 'Location needs approval')
        loc = {k: r.get(k, '') for k in ('id', 'name', 'address', 'iBeaconUUID', 'altBeaconUUID')}; loc['beaconMajorCode'] = integer(r.get('beaconMajorCode'), where)
        for k in ('id', 'name', 'address'):
            if not loc[k]: fail(where, 'Missing '+k)
        if not 0 <= loc['beaconMajorCode'] <= 65535: fail(where, 'Major out of range')
        for k in ('iBeaconUUID', 'altBeaconUUID'):
            try: uuid.UUID(loc[k])
            except ValueError: fail(where, 'Invalid '+k)
        locations.append(loc)
    location_ids = [r['id'] for r in locations]
    if len(location_ids) != len(set(location_ids)): fail('Locations', 'Duplicate IDs')
    string_ids = api_version in ('v2', 'v3')
    def trail_key(value): return canonical_trail_id(value) if string_ids else str(value or '').strip()
    trail_rows = {}
    for r in t['Trails']:
        trail_id = trail_key(r.get('id', ''))
        if trail_id in trail_rows: fail('Trails', 'Duplicate trail IDs')
        trail_rows[trail_id] = r
    if string_ids:
        for trail_id in sorted(set(routes) - set(trail_rows)):
            fail('KML route '+trail_id, 'No matching Trails row; add this canonical Trail ID to the master Sheet')
    endpoints = {}
    for trail_id, r in trail_rows.items():
        for role, column in (('start', 'startRecordKey'), ('end', 'endRecordKey')):
            key = str(r.get(column, '')).strip()
            if key: endpoints[(trail_id, role)] = key
    landmarks, places, beacon_keys, minors = [], {}, set(), {}
    for r in t['Beacons']:
        where = r.get('recordKey', 'Beacon')
        if not where or where == 'Beacon': fail(where, 'Missing recordKey')
        if where in beacon_keys: fail(where, 'Duplicate Beacon recordKey')
        beacon_keys.add(where)
        if r.get('reviewStatus') != 'Approved': fail(where, 'Needs review')
        if r.get('appStatus') not in ('Active', 'Draft', 'Retired'): fail(where, 'Invalid appStatus')
        if r.get('appStatus') != 'Active': continue
        # A blank Minor marks a place without a physical beacon.
        minor_text = str(r.get('id', '')).strip()
        minor = integer(minor_text, where) if minor_text else None
        if minor is not None:
            if not 0 <= minor <= 65535: fail(where, 'Minor out of range')
            if minor in minors: fail(where, f'Minor {minor} is also used by {minors[minor]}')
            minors[minor] = where
        if where not in points: fail(where, 'Active place has no KML Point')
        lm = {k: r.get(k, '') for k in ('name', 'category', 'description', 'longDescription', 'imagePath', 'imageAlt')}
        for k in ('name', 'category', 'description', 'longDescription', 'imagePath'):
            if not lm[k].strip(): fail(where, 'Missing '+k)
        if lm['category'] not in ('Trail', 'Building', 'PointOfInterest'): fail(where, 'Invalid category')
        if api_version == 'v3':
            lm['id'] = where
            if minor is not None: lm['beaconMinor'] = minor
        else:
            lm['id'] = minor
        lm['location'] = r.get('location', '')
        if lm['location'] not in location_ids: fail(where, 'Unknown location')
        try: lm['imagePath'] = normalize_image_path(lm['imagePath'])
        except ValueError as exc: fail(where, str(exc))
        asset = (ROOT/'server'/lm['imagePath']).resolve()
        if not asset.is_relative_to((ROOT/'server').resolve()) or not asset.is_file(): fail(where, 'Image file missing: '+lm['imagePath'])
        if where in points:
            lat, lon = points[where]['coordinate']; lm['coordinates'] = {'latitude': lat, 'longitude': lon}
        if r.get('isOpen') != '': lm['isOpen'] = boolean(r.get('isOpen'), where)
        if r.get('trailDistanceDescription'): lm['trailDistanceDescription'] = r['trailDistanceDescription']
        places[where] = {'landmark': lm, 'minor': minor}
        # Earlier contracts identify places by Minor, so they cannot include beacon-free places.
        if api_version == 'v3' or minor is not None: landmarks.append(lm)
    content, stops = {}, {}
    for r in t['Stop Content']:
        trail_id = trail_key(r.get('trailId', '')); record_key = str(r.get('recordKey', '')).strip()
        key = (trail_id, record_key)
        if key in content: fail(key, 'Duplicate Stop Content row')
        content[key] = {'distanceToNextClockwise': r.get('forwardDistance', ''), 'distanceToNextClockwiseDescription': r.get('forwardInstructions', ''),
                        'distanceToNextCounterClockwise': r.get('reverseDistance', ''), 'distanceToNextCounterClockwiseDescription': r.get('reverseInstructions', '')}
        if trail_id not in trail_rows: fail(key, 'Unknown Stop Content Trail ID: '+trail_id); continue
        stop_order = str(r.get('stopOrder', '')).strip()
        if not stop_order:
            if record_key not in (endpoints.get((trail_id, 'start')), endpoints.get((trail_id, 'end'))):
                fail(key, "Set Stop Order, or make this recordKey the trail's Start or End recordKey")
            continue
        order = integer(stop_order, key)
        if order < 1: fail(key, 'Stop Order must be positive'); continue
        if record_key not in places: fail(key, 'Tour stop is not an active Beacons row'); continue
        stops.setdefault(trail_id, []).append({'order': order, 'key': record_key})
    trails = []
    for trail_id, r in trail_rows.items():
        where = 'Trail '+trail_id
        group = trail_id if string_ids else r.get('kmlTrailGroupId', '')
        if r.get('reviewStatus') != 'Approved': fail(where, 'Trail needs approval')
        if group not in routes: fail(where, 'No KML route for '+group)
        output_id = trail_id if string_ids else integer(trail_id, where)
        if not trail_id: fail(where, 'Missing trail ID')
        tr = {'id': output_id, 'location': r.get('location', ''), 'name': r.get('name', ''), 'isOpen': boolean(r.get('isOpen'), where), 'trailDistanceDescription': r.get('trailDistanceDescription', '')}
        if tr['location'] not in location_ids: fail(where, 'Unknown location')
        members = sorted(stops.get(trail_id, []), key=lambda x: x['order'])
        if [x['order'] for x in members] != list(range(1, len(members)+1)): fail(where, 'Stop Order must be consecutive from 1')
        stop_points = []
        for member in members:
            place = places[member['key']]
            if api_version != 'v3' and place['minor'] is None: continue
            stop_points.append({'coordinate': points[member['key']]['coordinate'], 'content': content[(trail_id, member['key'])],
                                'landmarkId': member['key'] if api_version == 'v3' else place['minor']})
        if api_version != 'v3' and len(stop_points) == 1: stop_points = []
        anchors = list(stop_points)
        for role in ('start', 'end'):
            key = endpoints.get((trail_id, role))
            if not key: continue
            if key not in points: fail(where, f'{role.title()} recordKey {key} has no KML Point'); continue
            if places.get(key, {}).get('minor') is not None: fail(where, f'{role.title()} recordKey {key} is an active beacon; use a separate point')
            stop_content = content.get((trail_id, key), {})
            anchor = {'coordinate': points[key]['coordinate'], 'endpoint': True}
            anchors.insert(0, anchor) if role == 'start' else anchors.append(anchor)
            if api_version == 'v3':
                side = 'Clockwise' if role == 'start' else 'CounterClockwise'
                lat, lon = points[key]['coordinate']
                tr[role] = {'latitude': lat, 'longitude': lon, 'distance': stop_content.get('distanceToNext'+side, ''),
                            'directions': stop_content.get('distanceToNext'+side+'Description', '')}
        if endpoints.get((trail_id, 'start')) and endpoints.get((trail_id, 'start')) == endpoints.get((trail_id, 'end')):
            fail(where, 'Start and End recordKey must differ')
        if group in routes and routes[group]:
            tr['boundaryCoordinates'] = route_with_stops(routes[group], anchors) if anchors else [
                {'latitude': latitude, 'longitude': longitude} for latitude, longitude in _merge(routes[group])
            ]
        trails.append(tr)
    return {'locations': locations, 'trails': trails, 'landmarks': landmarks}, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('workbook', type=Path)
    parser.add_argument('--api-version', choices=('v1', 'v2', 'v3'), default='v1')
    parser.add_argument('--kml', type=Path, default=ROOT/'server/talking-trails.kml'); parser.add_argument('--output-dir', type=Path, required=True); args = parser.parse_args()
    out = args.output_dir.resolve()
    if out == ROOT or out.is_relative_to(ROOT/'server'): parser.error('Use a separate review output directory, never server/')
    out.mkdir(parents=True, exist_ok=True); baseline_path = ROOT/'server/api'/args.api_version/'trails.json'
    if args.api_version == 'v1' or not baseline_path.is_file(): baseline_path = ROOT/'server/warrington-trails.json'
    baseline = json.loads(baseline_path.read_text())
    try: candidate, errors = validate(tables(args.workbook), args.kml, args.api_version)
    except (ValueError, KeyError, zipfile.BadZipFile, ET.ParseError) as exc: candidate, errors = {}, [{'record': 'Input', 'issue': str(exc)}]
    with (out/'validation.csv').open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['record', 'issue']); w.writeheader(); w.writerows(errors)
    for name in ('candidate.json', 'changes.diff'): (out/name).unlink(missing_ok=True)
    if errors:
        print(f'Blocked: {len(errors)} issues. See {out / "validation.csv"}')
        for error in errors: print(f"  {error['record']}: {error['issue']}")
        return 1
    old = json.dumps(baseline, indent=2, ensure_ascii=False, sort_keys=True)+'\n'; new = json.dumps(candidate, indent=2, ensure_ascii=False, sort_keys=True)+'\n'
    (out/'candidate.json').write_text(new); (out/'changes.diff').write_text(''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile='current JSON', tofile='sheet + KML')))
    print(f'Validated. Candidate and diff written to {out}. Nothing published.'); return 0


if __name__ == '__main__': raise SystemExit(main())
