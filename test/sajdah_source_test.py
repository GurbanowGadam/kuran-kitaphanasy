import hashlib
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build_sajdah_markers import build_document

class SajdahSourceTests(unittest.TestCase):
    def test_official_capture_derives_exact_bundled_annotations(self):
        actual = json.loads((ROOT / 'assets/data/sajdah_markers.json').read_text())
        self.assertEqual(actual, build_document())
        self.assertEqual(len(actual['items']), 14)

    def test_release_manifest_authenticates_annotation_and_source_captures(self):
        hashes = json.loads((ROOT / 'assets/sources/full-content-manifest.json').read_text())['artifactHashes']
        for name in ('assets/data/sajdah_markers.json', 'assets/sources/diyanet-reading/isaretciler-response.json', 'assets/sources/diyanet-reading/isaretciler-decoded.json'):
            self.assertIn(name, hashes)
            self.assertEqual(hashes[name], hashlib.sha256((ROOT / name).read_bytes()).hexdigest())

if __name__ == '__main__':
    unittest.main()
