"""Offline meal font coverage: run with a Python environment with fontTools."""
import json
from pathlib import Path

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / 'assets/quran.json').read_text())
# Full modern Turkmen alphabet, plus Turkish letters and displayed verse ranges.
alphabet = 'AaBbÇçDdEeÄäFfGgHhIiJjŽžKkLlMmNnŇňOoÖöPpRrSsŞşTtUuÜüWwYyÝýZzĞğİı'
source = ''.join(
    block['translation'] + str(block['range']) + '. '
    for surah in data['surahs'] for block in surah['blocks']
)
required = {ord(c) for c in source + alphabet if not c.isspace()}
for name, weight in [('Regular', 400), ('Bold', 700)]:
    path = ROOT / f'assets/fonts/NotoSerif-{name}.ttf'
    with TTFont(path) as font:
        assert 'fvar' not in font, 'Must bundle fully static instances'
        assert font['OS/2'].usWeightClass == weight
        cmap = font.getBestCmap()
        missing = sorted(cp for cp in required if cp not in cmap or
                         cmap[cp] == '.notdef')
        assert not missing, f'{name}: missing {[hex(cp) for cp in missing]}'
        print(f'NotoSerif {name} ({weight}): {len(required)} required codepoints; 0 missing')
