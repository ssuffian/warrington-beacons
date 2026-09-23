import unittest
from group_master_review import coordinate_review


class CoordinateReviewTest(unittest.TestCase):
    def test_rounding_requires_both_axes(self):
        old={'coordinates':{'latitude':40.2388259,'longitude':-75.1691902}}
        row={'latitude':'40.239','longitude':'-75.169','sourceCoordinates':'40.239, -75.169'}
        self.assertEqual(coordinate_review(row,old)[0],'Consistent with rounding')
        row.update(longitude='-75.170',sourceCoordinates='40.239, -75.170')
        self.assertEqual(coordinate_review(row,old)[0],'Changed beyond rounding')
    def test_dms_is_compared_not_skipped(self):
        old={'coordinates':{'latitude':40.2453132,'longitude':-75.1752519}}
        row={'latitude':'40.246047222','longitude':'-75.178247222','sourceCoordinates':'40°14\x2745.77"N 75°10\x2741.69"W, '}
        label,distance,_=coordinate_review(row,old)
        self.assertEqual(label,'Changed beyond rounding')
        self.assertTrue(266<distance<268)
    def test_missing_axis_not_invented(self):
        row={'latitude':'40.1','longitude':'-75.1','sourceCoordinates':', -75.1'}
        self.assertEqual(coordinate_review(row,{'coordinates':{'latitude':40.1,'longitude':-75.1}})[0],'Incomplete source coordinates')


if __name__=='__main__': unittest.main()
