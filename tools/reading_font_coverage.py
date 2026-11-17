"""Measure the actual reader primary font; never infer coverage from an old font."""
import hashlib
from pathlib import Path
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
PRIMARY_FONT = 'assets/fonts/KuranIsaretler.ttf'  # Flutter DiyanetAmasya
NATIVE_MARKERS = '\u00a0﴿﴾٠١٢٣٤٥٦٧٨٩'
COVERAGE_CAVEAT = ('cmap presence is necessary, not a shaping/rendering proof. '
                   'The reader primary font is KuranIsaretler.ttf (DiyanetAmasya); '
                   'ShaikhHamdullahMushaf is historical, not the primary font. '
                   'Visual joining, diacritic placement and device rendering still need review.')
RENDERING_CAVEAT = 'Primary-font cmap coverage is measured in reading-font-coverage.json; visual/device rendering still needs review.'


def measure_fonts(items):
    chars = {c for v in items for c in v['text'] if not c.isspace()}
    reports = []
    for path in sorted((ROOT / 'assets/fonts').glob('*.ttf')):
        with TTFont(path) as font:
            cmap = font.getBestCmap() or {}
        missing = sorted(ord(c) for c in chars if ord(c) not in cmap)
        reports.append({'font': str(path.relative_to(ROOT)),
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'cmapEntries': len(cmap), 'requiredDistinctNonWhitespace': len(chars),
                        'missingCodepoints': [f'U+{c:04X}' for c in missing],
                        'missingCharacters': ''.join(map(chr, missing)), 'complete': not missing})
    with TTFont(ROOT / PRIMARY_FONT) as font:
        cmap = font.getBestCmap() or {}
    marker_missing = sorted({f'U+{ord(c):04X}' for c in NATIVE_MARKERS if ord(c) not in cmap})
    return {'applicationFonts': reports, 'primaryFont': PRIMARY_FONT,
            'nativeMarkers': {'requiredCodepoints': sorted({f'U+{ord(c):04X}' for c in NATIVE_MARKERS}),
                              'missingCodepoints': marker_missing, 'complete': not marker_missing,
                              'bidiControl': 'U+200F is a formatting control, tested through HarfBuzz rather than required as a visible cmap glyph.'},
            'warning': COVERAGE_CAVEAT}
