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


if __name__ == '__main__':
    unittest.main()
