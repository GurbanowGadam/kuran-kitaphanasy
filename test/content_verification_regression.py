"""Regression contracts for full offline verification (no network)."""
import json
import sys
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))

class VerificationRegression(unittest.TestCase):
    def test_metadata_builder_emits_all_archived_records(self):
        from build_full_content import build_titles_metadata
        build_titles_metadata()
        rows=json.loads((ROOT/'assets/sources/diyanet-reading/surahs-decoded.json').read_text())['data']
        titles=json.loads((ROOT/'assets/data/surah_titles_diyanet.json').read_text())
        meta=json.loads((ROOT/'assets/data/surah_metadata.json').read_text())
        self.assertEqual(titles['items'],[{'surah':r['id'],'name':r['ad_ar']} for r in rows])
        self.assertEqual(len(titles['items']),114)
        self.assertEqual(len(meta['items']),114)
        self.assertIn('all 114',titles['source']['field'])

    def test_poppler_bbox_preserves_low_body_line_but_not_footer(self):
        from check_full_content import poppler_columns
        raw=json.loads((ROOT/'assets/sources/pdf-extraction/all-pages.json').read_text())
        import re
        cols=poppler_columns(Path('/home/gadamgurban/Documents/kurany_kerim_turkmen_dilinde.pdf'),131)
        self.assertEqual(re.sub(r'\s+','',cols['left']),re.sub(r'\s+','',raw[130]['left']))
        self.assertTrue(cols['left'].endswith('(mugjyzalary)'))

    def test_independent_translation_report(self):
        from check_full_content import verify_translation_conservation
        report=verify_translation_conservation()
        self.assertEqual(len(report['surahs']),114)
        self.assertEqual(report['mismatchingSurahs'],[])
        self.assertEqual(report['humanReviewRequired'], [])

    def test_font_report_includes_all_heading_runs(self):
        report=json.loads((ROOT/'assets/sources/full-font-validation.json').read_text())
        self.assertEqual(report.get('shapedHeadingCount'),114)
        self.assertEqual(report.get('shapingMissingGlyphHeadings'),[])
        self.assertEqual(report.get('headingPrefix'),'سُورَةُ ')

if __name__=='__main__': unittest.main()
