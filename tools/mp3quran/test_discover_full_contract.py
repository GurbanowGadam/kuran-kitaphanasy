import unittest
try:
    from .discover_full_contract import validate_rows, range_total
except ImportError:
    from discover_full_contract import validate_rows, range_total

class ValidationTests(unittest.TestCase):
    def test_source_intervals(self):
        self.assertEqual(validate_rows([{'ayah':1,'start_time':0,'end_time':10}],1), [])
        self.assertTrue(validate_rows([{'ayah':1,'start_time':0,'end_time':10},{'ayah':2,'start_time':9,'end_time':12}],2))
        self.assertTrue(validate_rows([{'ayah':2,'start_time':0,'end_time':10}],2))
    def test_exact_prefix(self):
        self.assertEqual(range_total(206,'bytes 0-511/12345',b'x'*512),12345)
        with self.assertRaises(ValueError): range_total(200,'bytes 0-511/12345',b'x'*512)
        with self.assertRaises(ValueError): range_total(206,'bytes 0-511/12345',b'x'*511)

if __name__ == '__main__': unittest.main()
