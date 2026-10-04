import copy
import json
import unittest

from validate_api_contract import validate_document


ROOT = __import__('pathlib').Path(__file__).resolve().parents[1]
SCHEMA = json.loads((ROOT/'server/api/v1/schema.json').read_text())
DOCUMENT = json.loads((ROOT/'server/api/v1/trails.json').read_text())


class ApiContractTest(unittest.TestCase):
    def test_current_v1_data_satisfies_contract(self):
        self.assertEqual(validate_document(SCHEMA, DOCUMENT), [])

    def test_new_field_requires_contract_change(self):
        candidate = copy.deepcopy(DOCUMENT)
        candidate['locations'][0]['newField'] = 'would require v2'
        self.assertTrue(any('newField' in error for error in validate_document(SCHEMA, candidate)))

    def test_id_type_is_part_of_contract(self):
        candidate = copy.deepcopy(DOCUMENT)
        candidate['trails'][0]['id'] = str(candidate['trails'][0]['id'])
        self.assertTrue(any("is not of type 'integer'" in error for error in validate_document(SCHEMA, candidate)))

    def test_cross_record_references_are_checked(self):
        candidate = copy.deepcopy(DOCUMENT)
        candidate['landmarks'][0]['location'] = 'missing-location'
        self.assertTrue(any('unknown location' in error for error in validate_document(SCHEMA, candidate)))


V3_SCHEMA = json.loads((ROOT/'server/api/v3/schema.json').read_text())
V3_DOCUMENT = json.loads((ROOT/'server/api/v3/trails.json').read_text())


class ApiV3ContractTest(unittest.TestCase):
    def test_current_v3_data_satisfies_contract(self):
        self.assertEqual(validate_document(V3_SCHEMA, V3_DOCUMENT), [])

    def test_beacon_minor_is_optional_but_unique(self):
        candidate = copy.deepcopy(V3_DOCUMENT)
        del candidate['landmarks'][0]['beaconMinor']
        self.assertEqual(validate_document(V3_SCHEMA, candidate), [])
        candidate['landmarks'][0]['beaconMinor'] = candidate['landmarks'][1]['beaconMinor']
        self.assertTrue(any('duplicate beaconMinor' in error for error in validate_document(V3_SCHEMA, candidate)))

    def test_stop_references_use_place_record_keys(self):
        candidate = copy.deepcopy(V3_DOCUMENT)
        trail = next(t for t in candidate['trails'] if any('landmarkId' in p for p in t['boundaryCoordinates']))
        next(p for p in trail['boundaryCoordinates'] if 'landmarkId' in p)['landmarkId'] = 'NOPE-1'
        self.assertTrue(any('unknown landmark' in error for error in validate_document(V3_SCHEMA, candidate)))


if __name__ == '__main__':
    unittest.main()
