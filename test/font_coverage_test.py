"""Check the actual primary Arabic font, never the union of fallback cmaps.
Run: python3 test/font_coverage_test.py (fontTools required).
"""
import json
import re
from pathlib import Path
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]


def primary_font_path():
    dart = (ROOT / 'lib/reader/presentation/reader_content.dart').read_text()
    family = re.search(r"fontFamily: '(DiyanetAmasya)'", dart).group(1)
    manifest = (ROOT / 'pubspec.yaml').read_text()
    asset = re.search(r'family: ' + family + r'\s+fonts:\s+- asset: (\S+)', manifest).group(1)
    return ROOT / asset


if __name__ == '__main__':
    verses = json.loads((ROOT / 'assets/sources/arabic-verified.json').read_text())
    font = TTFont(primary_font_path())
    cmap = font.getBestCmap()
    missing = sorted({ord(c) for v in verses for c in v['arabic'] if ord(c) not in cmap})
    assert not missing, f'Primary font splits Arabic words across fonts: {[hex(c) for c in missing]}'
    print('PASS: primary Arabic font covers every source character without fallback')
    # RLM is a bidi format control, not a visible glyph requiring cmap coverage.
    manifest = (ROOT / 'pubspec.yaml').read_text()
    asset = re.search(r'family: DiyanetMarkers\s+fonts:\s+- asset: (\S+)', manifest).group(1)
    cmap = TTFont(ROOT / asset).getBestCmap()
    markers = '﴿﴾٠١٢٣٤٥٦٧٨٩\u00a0 '
    missing = sorted({ord(c) for c in markers if ord(c) not in cmap})
    assert not missing, f'Missing marker glyphs: {[hex(c) for c in missing]}'
    print('PASS: Diyanet marker font covers ornate brackets, all Arabic-Indic digits and spacing')
