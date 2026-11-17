"""Run with fontTools + uharfbuzz installed; tests real shaping, not cmap union."""
import json
import uharfbuzz as hb
from font_coverage_test import ROOT, primary_font_path

font = hb.Font(hb.Face(primary_font_path().read_bytes()))
hb.ot_font_set_funcs(font)


def shape(text, features=None):
    buf = hb.Buffer()
    buf.add_str(text)
    buf.direction = 'rtl'
    buf.script = 'arab'
    buf.language = 'ar'
    hb.shape(font, buf, features)
    return [(g.codepoint, g.cluster) for g in buf.glyph_infos]


verses = json.loads((ROOT / 'assets/sources/arabic-verified.json').read_text())
words = {word for verse in verses for word in verse['arabic'].split()}
for word in sorted(words):
    assert all(gid for gid, _ in shape(word)), f'Missing shaped glyph in {word!r}'

# U+06CC must select contextual GSUB forms, not merely have an isolated cmap entry.
# Initial: yawm; medial: rahim. Both are exact source words.
for word in ['یَوْمِ', 'الرَّحٖیمِ']:
    normal = shape(word)
    unjoined = shape(word, {'init': False, 'medi': False, 'fina': False, 'rlig': False, 'calt': False})
    assert normal != unjoined, f'Contextual shaping inactive for {word!r}'
    yeh_index = word.index('\u06cc')
    joined_yeh = [gid for gid, cluster in normal if cluster == yeh_index]
    isolated_yeh = [gid for gid, cluster in shape('\u06cc')]
    assert joined_yeh and joined_yeh != isolated_yeh, f'Yeh remained isolated in {word!r}'

# Font-level final-form probe only, not a replacement or added Quran verse.
assert shape('بی') != shape('بی', {'fina': False, 'init': False, 'rlig': False, 'calt': False})
print(f'PASS: {len(words)} exact source words shape without .notdef; U+06CC contextual forms active')
