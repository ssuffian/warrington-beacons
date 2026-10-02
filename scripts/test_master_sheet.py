import copy
import unittest

from master_sheet import ROOT, normalize_image_path, read_kml, tables, validate
from migrate_sheet_memberships import migrate


WORKBOOK = ROOT/'outputs/master-kml-source-of-truth-2026-09-23/warrington-master-review.xlsx'
KML = ROOT/'server/api/v1/talking-trails.kml'


class MasterValidationTest(unittest.TestCase):
    def setUp(self):
        self.tables = migrate(tables(WORKBOOK), KML, 'v1')

    def test_final_master_and_kml_generate_app_data(self):
        result, errors = validate(self.tables, KML)
        self.assertEqual(errors, [])
        self.assertEqual(len(result['landmarks']), 38)
        self.assertEqual(len(result['trails']), 4)

    def test_kml_controls_landmark_coordinates(self):
        result, errors = validate(self.tables, KML)
        self.assertEqual(errors, [])
        points, _, _ = read_kml(KML)
        rows = {r['recordKey']: r for r in self.tables['Beacons']}
        landmark = next(x for x in result['landmarks'] if x['id'] == int(rows['LP-2']['id']))
        lat, lon = points['LP-2']['coordinate']
        self.assertEqual(landmark['coordinates'], {'latitude': lat, 'longitude': lon})

    def test_sheet_stop_order_controls_tour_order(self):
        result, errors = validate(self.tables, KML)
        self.assertEqual(errors, [])
        green = next(t for t in result['trails'] if t['id'] == 3001)
        self.assertEqual([p['landmarkId'] for p in green['boundaryCoordinates'] if 'landmarkId' in p],
                         [3001, 2004, 3005, 2005, 3008, 2006])

    def test_sheet_order_overrides_existing_kml_order(self):
        candidate = copy.deepcopy(self.tables)
        rows = [r for r in candidate['Beacons'] if r['trailId'] == '3001']
        for row in rows: row['stopOrder'] = str(len(rows) + 1 - int(row['stopOrder']))
        result, errors = validate(candidate, KML)
        self.assertEqual(errors, [])
        green = next(t for t in result['trails'] if t['id'] == 3001)
        self.assertEqual([p['landmarkId'] for p in green['boundaryCoordinates'] if 'landmarkId' in p],
                         [2006, 3008, 2005, 3005, 2004, 3001])

    def test_clearing_sheet_membership_makes_route_stopless(self):
        candidate = copy.deepcopy(self.tables)
        for row in candidate['Beacons']:
            if row['trailId'] == '3001': row.update(trailId='', stopOrder='')
        candidate['Stop Content'] = [r for r in candidate['Stop Content'] if r['trailId'] != '3001']
        result, errors = validate(candidate, KML)
        self.assertEqual(errors, [])
        green = next(t for t in result['trails'] if t['id'] == 3001)
        self.assertFalse(any('landmarkId' in p for p in green['boundaryCoordinates']))

    def test_missing_columns_unknown_trail_and_invalid_order_block_generation(self):
        for changes in ({'trailId':'unknown'}, {'stopOrder':'0'}, {'stopOrder':''}, {'stopOrder':'2'}):
            with self.subTest(changes=changes):
                candidate = copy.deepcopy(self.tables)
                next(r for r in candidate['Beacons'] if r['trailId'] == '3001' and r['stopOrder'] == '1').update(changes)
                self.assertTrue(validate(candidate, KML)[1])
        self.assertTrue(validate(tables(WORKBOOK), KML)[1])

    def test_migration_does_not_overwrite_sheet_edits(self):
        self.tables['Beacons'][0].update(trailId='', stopOrder='')
        self.assertEqual(migrate(self.tables, KML, 'v1')['Beacons'][0]['trailId'], '')

    def test_v2_sheet_membership_uses_canonical_string_ids(self):
        candidate = copy.deepcopy(self.tables)
        ids = {'1002': 'yellow-trail', '3001': 'green-trail',
               '3002': 'kids-mountain-trail', '4001': 'route-202-connector-trail'}
        for row in candidate['Trails']: row['id'] = ids[row['id']]
        for row in candidate['Stop Content']: row['trailId'] = ids[row['trailId']]
        for row in candidate['Beacons']:
            if row['trailId']: row['trailId'] = ids[row['trailId']].replace('-', ' ').title()
        result, errors = validate(candidate, ROOT/'server/talking-trails.kml', 'v2')
        self.assertEqual(errors, [])
        green = next(t for t in result['trails'] if t['id'] == 'green-trail')
        self.assertEqual([p['landmarkId'] for p in green['boundaryCoordinates'] if 'landmarkId' in p],
                         [3001, 2004, 3005, 2005, 3008, 2006])

    def test_unapproved_content_blocks_generation(self):
        candidate = copy.deepcopy(self.tables)
        candidate['Beacons'][0]['reviewStatus'] = 'Needs Review'
        self.assertTrue(any(e['record'] == candidate['Beacons'][0]['recordKey'] for e in validate(candidate, KML)[1]))

    def test_clickable_hosted_image_url_is_normalized_for_existing_apps(self):
        candidate = copy.deepcopy(self.tables)
        row = next(r for r in candidate['Beacons'] if r['appStatus'] == 'Active')
        relative = normalize_image_path(row['imagePath'])
        row['imagePath'] = 'https://trails.warringtoneac.org/' + relative
        result, errors = validate(candidate, KML)
        self.assertEqual(errors, [])
        landmark = next(x for x in result['landmarks'] if x['id'] == int(row['id']))
        self.assertEqual(landmark['imagePath'], relative)

    def test_external_image_url_is_rejected(self):
        with self.assertRaises(ValueError):
            normalize_image_path('https://example.com/photo.jpg')


if __name__ == '__main__': unittest.main()
