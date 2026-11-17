"""Full production source ingestion regression tests (stdlib unittest)."""
import importlib.util
import sys
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))

class FullContent(unittest.TestCase):
    def test_full_builder_exists(self):
        self.assertIsNotNone(importlib.util.find_spec('build_full_content'), 'full source parser missing')

    def test_grouped_markers(self):
        if importlib.util.find_spec('build_full_content') is None:
            self.fail('full source parser missing')
        from build_full_content import parse_numbers
        self.assertEqual(parse_numbers('1, 2, 3, 4'), [1, 2, 3, 4])
        self.assertEqual(parse_numbers('1-4'), [1, 2, 3, 4])

    def test_complete_translation_coverage(self):
        import json
        data = json.loads((ROOT/'assets/data/translations.json').read_text())
        metadata = json.loads((ROOT/'assets/sources/diyanet-reading/surahs-decoded.json').read_text())['data']
        actual = [(t['surah'], a) for t in data['items'] for a in range(t['fromAyah'], t['toAyah']+1)]
        expected = [(s['id'], a) for s in metadata for a in range(1, s['ayet_sayisi']+1)]
        self.assertEqual(actual, expected)

class ProductionIntegrity(unittest.TestCase):
    def test_independent_full_validator(self):
        self.assertIsNotNone(importlib.util.find_spec('check_full_content'),'full integrity checker missing')

    def test_independent_pdf_extraction_report(self):
        import json
        path=ROOT/'assets/sources/full-turkmen-pdf-extraction-validation.json'
        self.assertTrue(path.exists(),'full independent PDF extraction validation missing')
        report=json.loads(path.read_text())
        self.assertEqual(report['checkedColumns'],1210)
        self.assertEqual(report['mismatches'],[])

    def test_full_arabic_and_page_coverage(self):
        import json
        verses=json.loads((ROOT/'assets/data/verses.json').read_text())['items']
        pages=json.loads((ROOT/'assets/data/pages.json').read_text())['items']
        self.assertEqual(len(verses),6236)
        self.assertEqual(len(pages),605)
        self.assertEqual([(v['surah'],v['ayah']) for v in verses],[(v['surah'],v['ayah']) for p in pages for v in p['verses']])
        self.assertEqual(pages[0]['verses'][-1],{'surah':1,'ayah':7})
        self.assertEqual(pages[1]['verses'][0],{'surah':2,'ayah':1})

    def test_font_all_source_shaping(self):
        import json
        p=ROOT/'assets/sources/full-font-validation.json'
        self.assertTrue(p.exists(),'full primary-font validation missing')
        report=json.loads(p.read_text())
        self.assertEqual(report['primaryMissingCodepoints'],[])
        self.assertEqual(report['shapingMissingGlyphVerses'],[])
        self.assertEqual(report['shapedVerseCount'],6236)
        self.assertEqual(len(report.get('turkmenFonts',[])),2,'both meal font checks required')
        self.assertTrue(all(not x['missingCodepoints'] for x in report['turkmenFonts']))

    def test_full_source_character_conservation(self):
        import json,re
        data={n:json.loads((ROOT/f'assets/data/{n}.json').read_text())['items'] for n in ['translations','surah_descriptions','surah_names_pdf','footnotes']}
        raw=json.loads((ROOT/'assets/sources/pdf-extraction/all-pages.json').read_text())
        original='\n'.join(p[side] for p in raw for side in ('left','right'))
        headings=list(re.finditer(r'(?m)^\d+-(?:nji|njy) süre:.*$|^52-nji: «Tur» süresi$',original))
        def compact(s):return re.sub(r'\s+','',s.replace('soraýa-\nrys','soraýarys'))
        notes={n['id']:n for n in data['footnotes']}
        for i,h in enumerate(headings):
            surah=i+1;body=original[h.start():headings[i+1].start() if i+1<len(headings) else len(original)]
            assembled=data['surah_names_pdf'][i]['originalHeading']+data['surah_descriptions'][i]['text']
            if surah not in (1,9):assembled+='Rahman (Mähriban) we Rahym (Rehim-şepagatly) Allanyň ady bilen'
            for t in data['translations']:
                if t['surah']!=surah:continue
                self.assertIn('sourceMarker',t,'exact source punctuation required for independent conservation')
                assembled+=t['sourceMarker']+t['text']+''.join(notes[n]['text'] for n in t['footnoteIds'])
            self.assertEqual(compact(assembled),compact(body),f'Unicode source characters lost/changed in surah {surah}')

    def test_parser_deterministic_and_full_notes(self):
        from build_full_content import translations
        a,b,c,d=translations()
        self.assertEqual(len(a),5905)
        self.assertEqual(len(b),203)
        self.assertEqual(len(c),114)
        self.assertEqual(translations(),(a,b,c,d))
        self.assertEqual(next(x for x in a if x['id']=='79:40-41')['sourceLabel'],'40')

if __name__ == '__main__': unittest.main()
