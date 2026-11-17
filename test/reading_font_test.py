"""Complete 6236-verse dataset regression; requires fontTools and uharfbuzz.
Legacy cached-source tests remain independent. No glyph test certifies visual layout.
"""
import json
import sys
import unittest
from pathlib import Path

import uharfbuzz as hb
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
FONT = ROOT / 'assets/fonts/KuranIsaretler.ttf'
VERSES = json.loads((ROOT / 'assets/data/verses.json').read_text())['items']
MARKERS = '\u00a0\u200f﴿﴾٠١٢٣٤٥٦٧٨٩'


class ReadingFontTest(unittest.TestCase):
    def test_current_source_and_native_marker_cmap(self):
        metadata = json.loads((ROOT / 'assets/data/surah_metadata.json').read_text())['items']
        self.assertEqual(len(VERSES), 6236)
        self.assertEqual([(v['surah'], v['ayah']) for v in VERSES],
                         [(s['surah'], a) for s in metadata for a in range(1, s['verseCount'] + 1)])
        with TTFont(FONT) as font:
            cmap = font.getBestCmap()
        required = set(''.join(v['text'] for v in VERSES) + MARKERS)
        # RLM is a bidi control, not a visible glyph; HarfBuzz handles it below.
        missing = sorted(f'U+{ord(c):04X}' for c in required if c != '\u200f' and not c.isspace() and ord(c) not in cmap)
        self.assertEqual(missing, [])

    def test_metadata_identifies_actual_primary_font(self):
        report = json.loads((ROOT / 'assets/sources/full-font-validation.json').read_text())
        self.assertEqual(report.get('primaryFont'), 'assets/fonts/KuranIsaretler.ttf')
        self.assertNotIn('UI must supply a compatible fallback', report['warning'])
        from reading_font_coverage import measure_fonts
        for key, value in measure_fonts(VERSES).items():
            self.assertEqual(report[key], value, key)
        self.assertEqual(report['shapedVerseCount'], 6236)
        self.assertEqual(report['shapedHeadingCount'], 114)
        self.assertEqual(report['shapingMissingGlyphVerses'], [])
        self.assertEqual(report['shapingMissingGlyphHeadings'], [])
        self.assertIn('visual', report['caveat'])

    def test_real_shaping_all_words_verses_and_markers(self):
        font = hb.Font(hb.Face(FONT.read_bytes()))
        hb.ot_font_set_funcs(font)
        def shape(text, features=None):
            buf = hb.Buffer()
            buf.add_str(text)
            buf.direction, buf.script, buf.language = 'rtl', 'arab', 'ar'
            hb.shape(font, buf, features)
            return [(g.codepoint, g.cluster) for g in buf.glyph_infos]
        words = {w for v in VERSES for w in v['text'].split()}
        runs = list(words)
        for v in VERSES:
            digits = ''.join('٠١٢٣٤٥٦٧٨٩'[int(d)] for d in str(v['ayah']))
            runs.append(v['text'] + '\u00a0\u200f﴿' + digits + '﴾\u200f')
        runs.append(MARKERS)
        for text in runs:
            with self.subTest(text=text):
                glyphs = shape(text)
                self.assertTrue(glyphs)
                self.assertTrue(all(gid for gid, _ in glyphs), 'HarfBuzz emitted .notdef')
        # Exact source words must activate contextual forms, not just map glyphs.
        probes = [w for w in words if 'ي' in w and len(w) > 3]
        self.assertTrue(probes)
        self.assertTrue(any(shape(w) != shape(w, {'init': False, 'medi': False, 'fina': False,
                                                 'rlig': False, 'calt': False}) for w in probes))
        print(f'PASS: {len(words)} current-source words, {len(VERSES)} marked verses and native marker repertoire shaped without .notdef')


if __name__ == '__main__':
    unittest.main()
