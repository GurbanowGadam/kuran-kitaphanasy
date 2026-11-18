"""Build exact translation fixture from saved pdftotext column crops.
Only whitespace and the line-wrapped word soraýa-rys are normalized.
Lexical hyphens (Rehim-şepagatly, haýyr-sahawat) are retained.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'assets/sources'

def normalize(s):
    s = re.sub(r'-\s*\n\s*', '-', s)
    s = ' '.join(s.split())
    return s.replace('soraýa-rys', 'soraýarys')

f = (SRC / 'fatiha-right.txt').read_text()
b = (SRC / 'bakara-left.txt').read_text() + '\n' + (SRC / 'bakara-right.txt').read_text()
y = (SRC / 'ikhlas-left.txt').read_text()
fat = []
for n in range(1, 8):
    start = re.search(rf'(?m)^{n}\.\s*', f).end()
    end = re.search(r'\n\s*\n', f[start:]).start() + start
    fat.append(normalize(f[start:end]))
bak = []
for n in range(1, 6):
    start = re.search(rf'(?m)^{n}\.\s*', b).end()
    if n == 2:
        end = re.search(r'(?m)^3\.', b).start()
    else:
        end = re.search(r'\n\s*\n', b[start:]).start() + start
    bak.append(normalize(b[start:end]))
yhlas = normalize(y.split('1, 2, 3, 4. ', 1)[1].strip('\n\f '))
result = {'1': fat, '2': bak, '112': [yhlas]}
(ROOT / 'test/translation_expected.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False, indent=2))
