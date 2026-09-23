import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NS = {'k': 'http://www.opengis.net/kml/2.2'}

class GroupedKmlTest(unittest.TestCase):
    def test_served_routes_have_stable_group_and_location(self):
        root = ET.parse(ROOT / 'server/talking-trails.kml').getroot()
        folders = root.findall('.//k:Folder', NS)
        self.assertEqual([f.get('id') for f in folders],
                         ['routes-lions-pride-park', 'routes-us-202', 'routes-location-review'])
        routes = []
        for pm in root.findall('.//k:Placemark', NS):
            if pm.find('.//k:LineString', NS) is None and pm.find('.//k:Polygon', NS) is None: continue
            data = {d.get('name'): d.findtext('k:value', default='', namespaces=NS)
                    for d in pm.findall('k:ExtendedData/k:Data', NS)}
            self.assertIn(data.get('location'), {'lions-pride-park', 'us-202', 'unassigned'})
            self.assertTrue(data.get('trailGroupId'))
            routes.append((pm.findtext('k:name', namespaces=NS), data))
        self.assertEqual(len(routes), 15)
        self.assertEqual({d['trailGroupId'] for n,d in routes if n == 'Mill Creek Preserve Trail'}, {'mill-creek-preserve-trail'})
        self.assertEqual({d['trailGroupId'] for n,d in routes if n == 'Kids Mt. Trail'}, {'kids-mountain-trail'})
        points = root.findall('.//k:Point/..', NS)
        self.assertEqual(len(points), 57)
        stop_orders = []
        for point in points:
            data = {d.get('name'): d.findtext('k:value', default='', namespaces=NS)
                    for d in point.findall('k:ExtendedData/k:Data', NS)}
            self.assertTrue(data.get('recordKey'))
            if data.get('trailId'):
                stop_orders.append((data['trailId'], int(data['stopOrder'])))
        self.assertEqual(len(stop_orders), 30)

if __name__ == '__main__': unittest.main()
