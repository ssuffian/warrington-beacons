import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

from master_sheet import ROOT, KNS, canonical_trail_id, normalize_image_path, read_kml, tables, validate
from migrate_tour_stops import OLD_ORDER, OLD_TRAIL, migrate


FIXTURES = ROOT/'scripts/fixtures'
KML = ROOT/'server/talking-trails.kml'


def stop_ids(trail):
    return [p['landmarkId'] for p in trail['boundaryCoordinates'] if 'landmarkId' in p]


class MasterValidationTest(unittest.TestCase):
    def setUp(self):
        self.tables = json.loads((FIXTURES/'master-tour-stops.json').read_text())
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.kml = Path(self.temp.name)/'fixture.kml'
        # This historical Sheet fixture contains eleven routes. Keep its geometry
        # tests scoped to those routes; full-source coverage is tested separately.
        trail_ids = {canonical_trail_id(r['id']) for r in self.tables['Trails']}
        tree = ET.parse(KML)
        for parent in tree.getroot().iter():
            for pm in list(parent):
                if pm.tag != '{'+KNS['k']+'}Placemark' or pm.find('k:Point', KNS) is not None:
                    continue
                route_id = pm.findtext('k:ExtendedData/k:Data[@name="trailId"]/k:value', '', KNS)
                if route_id and canonical_trail_id(route_id) not in trail_ids:
                    parent.remove(pm)
        tree.write(self.kml)

    def generate(self, api_version='v3', candidate=None):
        return validate(candidate or self.tables, self.kml, api_version)

    def test_full_kml_reports_omitted_routes_in_both_release_versions(self):
        for version in ('v2', 'v3'):
            with self.subTest(version=version):
                _, errors = validate(self.tables, KML, version)
                missing = {e['record'] for e in errors if 'No matching Trails row' in e['issue']}
                self.assertEqual(missing, {'KML route emerson-preserve-trail',
                                           'KML route kings-court-access',
                                           'KML route outdoor-classroom-trail'})

    def test_unlisted_route_blocks_cli_without_replacing_published_data(self):
        out = Path(self.temp.name)/'review'
        out.mkdir()
        (out/'candidate.json').write_text('stale candidate')
        (out/'changes.diff').write_text('stale diff')
        published = ROOT/'server/api/v3/trails.json'
        before = published.read_bytes()
        result = subprocess.run([sys.executable, str(ROOT/'scripts/master_sheet.py'),
                                 str(FIXTURES/'live-sheet-2026-10-04'), '--kml', str(KML),
                                 '--api-version', 'v3', '--output-dir', str(out)],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('KML route emerson-preserve-trail', result.stdout)
        self.assertFalse((out/'candidate.json').exists())
        self.assertFalse((out/'changes.diff').exists())
        self.assertEqual(published.read_bytes(), before)

    def trail(self, result, trail_id):
        return next(t for t in result['trails'] if t['id'] == trail_id)

    def content_row(self, candidate, trail_id, record_key):
        return next(r for r in candidate['Stop Content']
                    if r['trailId'].lower() == trail_id and r['recordKey'] == record_key)

    def test_sheet_and_kml_generate_v2_and_v3(self):
        for version in ('v2', 'v3'):
            with self.subTest(version=version):
                result, errors = self.generate(version)
                self.assertEqual(errors, [])
                self.assertEqual(len(result['trails']), 11)

    def test_v3_places_use_record_keys_and_optional_beacon_minor(self):
        candidate = copy.deepcopy(self.tables)
        next(r for r in candidate['Beacons'] if r['recordKey'] == 'EAC-3')['id'] = ''
        result, errors = self.generate('v3', candidate)
        self.assertEqual(errors, [])
        places = {x['id']: x for x in result['landmarks']}
        self.assertEqual(places['EAC-2']['beaconMinor'], 1)
        self.assertNotIn('beaconMinor', places['EAC-3'])
        self.assertEqual(stop_ids(self.trail(result, 'weisel-preserve-trail')), ['EAC-2', 'EAC-3', 'EAC-4'])

    def test_v2_omits_places_without_a_beacon(self):
        candidate = copy.deepcopy(self.tables)
        next(r for r in candidate['Beacons'] if r['recordKey'] == 'EAC-3')['id'] = ''
        result, errors = self.generate('v2', candidate)
        self.assertEqual(errors, [])
        self.assertNotIn(2, [x['id'] for x in result['landmarks']])
        self.assertEqual(stop_ids(self.trail(result, 'weisel-preserve-trail')), [1, 3])

    def test_kml_controls_place_coordinates(self):
        result, errors = self.generate()
        self.assertEqual(errors, [])
        points, _, _ = read_kml(KML, 'v3')
        place = next(x for x in result['landmarks'] if x['id'] == 'LP-2')
        lat, lon = points['LP-2']['coordinate']
        self.assertEqual(place['coordinates'], {'latitude': lat, 'longitude': lon})

    def test_stop_order_controls_tour_order(self):
        candidate = copy.deepcopy(self.tables)
        rows = [r for r in candidate['Stop Content'] if r['trailId'] == 'green-trail']
        for row in rows: row['stopOrder'] = str(len(rows) + 1 - int(row['stopOrder']))
        result, errors = self.generate('v3', candidate)
        self.assertEqual(errors, [])
        self.assertEqual(stop_ids(self.trail(result, 'green-trail')), ['LP-16', 'LP-25', 'LP-15', 'LP-3'])

    def test_place_can_be_a_stop_on_two_trails(self):
        candidate = copy.deepcopy(self.tables)
        candidate['Stop Content'].append({**self.content_row(candidate, 'yellow-trail', 'LP-27'),
                                          'trailId': 'green-trail', 'stopOrder': '5'})
        result, errors = self.generate('v3', candidate)
        self.assertEqual(errors, [])
        self.assertIn('LP-27', stop_ids(self.trail(result, 'yellow-trail')))
        self.assertEqual(stop_ids(self.trail(result, 'green-trail'))[-1], 'LP-27')

    def test_invalid_tour_stops_block_generation(self):
        cases = {
            'gap': lambda c: self.content_row(c, 'green-trail', 'LP-16').update(stopOrder='9'),
            'blank order': lambda c: self.content_row(c, 'green-trail', 'LP-16').update(stopOrder=''),
            'zero order': lambda c: self.content_row(c, 'green-trail', 'LP-16').update(stopOrder='0'),
            'unknown trail': lambda c: self.content_row(c, 'green-trail', 'LP-16').update(trailId='no-such-trail'),
            'retired place': lambda c: next(r for r in c['Beacons'] if r['recordKey'] == 'LP-16').update(appStatus='Retired'),
            'duplicate minor': lambda c: next(r for r in c['Beacons'] if r['recordKey'] == 'LP-16').update(id='1'),
        }
        for label, change in cases.items():
            with self.subTest(label):
                candidate = copy.deepcopy(self.tables)
                change(candidate)
                self.assertTrue(self.generate('v3', candidate)[1])

    def test_trail_start_and_end_are_beacon_free_points(self):
        result, errors = self.generate('v3')
        self.assertEqual(errors, [])
        points, _, _ = read_kml(KML, 'v3')
        lower = self.trail(result, 'lower-nike-trail')
        self.assertEqual((lower['end']['latitude'], lower['end']['longitude']), points['JSON-16']['coordinate'])
        self.assertEqual(lower['end']['directions'], '858 yards to Waterfowl')
        self.assertNotIn('start', lower)
        connector = self.trail(result, 'route-202-connector-trail')
        self.assertIn('start', connector)
        self.assertEqual(stop_ids(connector), [])
        self.assertNotIn('JSON-16', [x['id'] for x in result['landmarks']])

    def test_trail_start_cannot_be_an_active_beacon(self):
        candidate = copy.deepcopy(self.tables)
        next(r for r in candidate['Trails'] if r['id'] == 'green-trail')['startRecordKey'] = 'LP-3'
        self.assertTrue(any('active beacon' in e['issue'] for e in self.generate('v3', candidate)[1]))

    def test_v3_allows_a_single_stop_and_keeps_the_whole_route(self):
        candidate = copy.deepcopy(self.tables)
        candidate['Stop Content'] = [r for r in candidate['Stop Content']
                                     if not (r['trailId'] == 'kids-mountain-trail' and r['recordKey'] == 'LP-7')]
        full, _ = self.generate('v3')
        result, errors = self.generate('v3', candidate)
        self.assertEqual(errors, [])
        kids = self.trail(result, 'kids-mountain-trail')
        self.assertEqual(stop_ids(kids), ['LP-19'])
        self.assertGreater(len(kids['boundaryCoordinates']), 2)
        v2, errors = self.generate('v2', candidate)
        self.assertEqual(errors, [])
        self.assertEqual(stop_ids(self.trail(v2, 'kids-mountain-trail')), [])
        self.assertTrue(full)

    def test_unapproved_content_blocks_generation(self):
        candidate = copy.deepcopy(self.tables)
        candidate['Beacons'][0]['reviewStatus'] = 'Needs Review'
        self.assertTrue(any(e['record'] == candidate['Beacons'][0]['recordKey'] for e in self.generate('v3', candidate)[1]))

    def test_clickable_hosted_image_url_is_normalized_for_existing_apps(self):
        result, errors = self.generate('v3')
        self.assertEqual(errors, [])
        row = next(r for r in self.tables['Beacons'] if r['appStatus'] == 'Active')
        self.assertTrue(row['imagePath'].startswith('https://trails.warringtoneac.org/'))
        place = next(x for x in result['landmarks'] if x['id'] == row['recordKey'])
        self.assertEqual(place['imagePath'], normalize_image_path(row['imagePath']))

    def test_external_image_url_is_rejected(self):
        with self.assertRaises(ValueError):
            normalize_image_path('https://example.com/photo.jpg')


class TourStopMigrationTest(unittest.TestCase):
    def test_migration_moves_membership_and_preserves_column_order(self):
        source = tables(FIXTURES/'live-sheet-2026-10-04')
        beacon_columns = list(source['Beacons'][0])
        content_columns = list(source['Stop Content'][0])
        result, report = migrate(source)
        self.assertEqual(list(result['Beacons'][0]),
                         [OLD_TRAIL if k == 'trailId' else OLD_ORDER if k == 'stopOrder' else k for k in beacon_columns])
        self.assertEqual(list(result['Stop Content'][0]), content_columns + ['stopOrder'])
        self.assertEqual(list(result['Trails'][0])[-2:], ['startRecordKey', 'endRecordKey'])
        weisel = [(r['recordKey'], r['stopOrder']) for r in result['Stop Content'] if r['trailId'] == 'Weisel-Preserve-Trail']
        self.assertEqual(weisel, [('EAC-2', '1'), ('EAC-3', '2'), ('EAC-4', '3')])
        self.assertTrue(any(line.startswith('LP-23:') for line in report))


if __name__ == '__main__': unittest.main()
