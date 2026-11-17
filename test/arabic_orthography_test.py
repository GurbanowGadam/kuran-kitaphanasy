"""Never silently substitute a different orthographic edition for Diyanet group 4."""
import json
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def load(path):
    return json.loads((ROOT / path).read_text())
class ArabicOrthographyTest(unittest.TestCase):
    def test_previous_shared_verses_exact_codepoints(self):
        current = {(v['surah'], v['ayah']): v['text'] for v in load('assets/data/verses.json')['items']}
        old = load('assets/sources/arabic-verified.json')
        shared = [v for v in old if (v['surah'], v['ayah']) in current]
        self.assertEqual(len(shared), len(old))
        for v in shared:
            with self.subTest(verse=(v['surah'], v['ayah'])):
                self.assertEqual(current[v['surah'], v['ayah']], v['arabic'])
    def test_all_6236_have_official_group4_provenance(self):
        data = load('assets/data/verses.json')
        self.assertEqual(data['source'].get('textGroup'), 4)
        self.assertEqual(data['source']['status'], 'complete')
        metadata = load('assets/data/surah_metadata.json')['items']
        self.assertEqual(len(data['items']), 6236)
        self.assertEqual([(v['surah'],v['ayah']) for v in data['items']],
                         [(s['surah'], a) for s in metadata for a in range(1,s['verseCount']+1)])
    def test_all_strings_match_official_captures_without_normalization(self):
        data = load('assets/data/verses.json')
        expected = []
        for capture in data['source']['captures']:
            for v in load(capture['path'])['data']:
                text = next(t['metin'] for t in v['metinler'] if t['metin_grubu_id'] == 4)
                expected.append({'surah':v['sure_id'], 'ayah':v['ayet_no'], 'text':text})
        self.assertEqual(data['items'], expected)
    def test_non_arabic_datasets_unchanged(self):
        import hashlib
        for path, expected in load('assets/sources/full-content-manifest.json')['artifactHashes'].items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(), expected, path)
if __name__ == '__main__':
    unittest.main()
