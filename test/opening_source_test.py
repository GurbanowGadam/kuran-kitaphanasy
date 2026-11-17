"""Opening-only provenance and primary font coverage; no scripture rewriting."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from capture_diyanet_reading import decode
import re


class OpeningSourceTest(unittest.TestCase):
    def test_official_titles_and_transport(self):
        doc = json.loads((ROOT / 'assets/data/surah_titles_diyanet.json').read_text())
        source = doc['source']
        raw = (ROOT / source['responsePath']).read_bytes()
        decoded = (ROOT / source['decodedPath']).read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), source['responseSha256'])
        self.assertEqual(hashlib.sha256(decoded).hexdigest(), source['decodedSha256'])
        js = (ROOT / 'assets/sources/diyanet-reading/public-client.js').read_bytes()
        key = re.search(rb'const \w+="([0-9a-f]{64})";let \w+=null;function', js)[1].decode()
        self.assertEqual(decode(raw, key), decoded)
        rows = {r['id']: r for r in json.loads(decoded)['data']}
        self.assertEqual([r['surah'] for r in doc['items']], list(range(1, 115)))
        font = TTFont(ROOT / 'assets/fonts/KuranIsaretler.ttf').getBestCmap()
        for item in doc['items']:
            self.assertEqual(item['name'], rows[item['surah']]['ad_ar'])
            heading = 'سُورَةُ ' + item['name']
            self.assertFalse({ord(c) for c in heading if not c.isspace()} - font.keys())
        self.assertFalse(rows[1]['besmele_gorunur'])
        self.assertTrue(rows[2]['besmele_gorunur'])
        self.assertFalse(rows[9]['besmele_gorunur'])

    def test_canonical_data_bytes_unchanged(self):
        baseline = json.loads((ROOT / 'test/fixtures/approved_demo_content.json').read_text())
        for name in ('verses', 'translations', 'pages', 'footnotes', 'surah_descriptions'):
            current = json.loads((ROOT / f'assets/data/{name}.json').read_text())['items']
            self.assertEqual(len(current[:len(baseline[name])]), len(baseline[name]))
            for expected, actual in zip(baseline[name], current):
                self.assertEqual({k: actual[k] for k in expected}, expected, name)


if __name__ == '__main__':
    unittest.main()
