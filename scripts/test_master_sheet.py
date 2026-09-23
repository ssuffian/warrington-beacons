import copy
import unittest

from master_sheet import ROOT, read_kml, tables, validate


WORKBOOK = ROOT/'outputs/master-kml-source-of-truth-2026-09-23/warrington-master-review.xlsx'
KML = ROOT/'server/talking-trails.kml'


class MasterValidationTest(unittest.TestCase):
    def setUp(self):
        self.tables = tables(WORKBOOK)

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

    def test_kml_stop_order_controls_tour_order(self):
        result, errors = validate(self.tables, KML)
        self.assertEqual(errors, [])
        green = next(t for t in result['trails'] if t['id'] == 3001)
        self.assertEqual([p['landmarkId'] for p in green['boundaryCoordinates'] if 'landmarkId' in p],
                         [3001, 2004, 3005, 2005, 3008, 2006])

    def test_unapproved_content_blocks_generation(self):
        candidate = copy.deepcopy(self.tables)
        candidate['Beacons'][0]['reviewStatus'] = 'Needs Review'
        self.assertTrue(any(e['record'] == candidate['Beacons'][0]['recordKey'] for e in validate(candidate, KML)[1]))


if __name__ == '__main__': unittest.main()
