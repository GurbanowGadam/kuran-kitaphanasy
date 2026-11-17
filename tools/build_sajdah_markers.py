#!/usr/bin/env python3
"""Derive sajdah annotations from the frozen ordinary public Diyanet marker API."""
import hashlib
import json
import re
from pathlib import Path
from capture_diyanet_reading import decode
ROOT = Path(__file__).resolve().parents[1]

def build_document():
    folder = ROOT / 'assets/sources/diyanet-reading'
    raw_path, decoded_path = (folder / f'isaretciler-{kind}.json' for kind in ('response','decoded'))
    raw, decoded = raw_path.read_bytes(), decoded_path.read_bytes()
    client = folder / 'public-client.js'
    key = re.search(rb'const \w+="([0-9a-f]{64})";let \w+=null;function', client.read_bytes())[1].decode()
    assert decode(raw, key) == decoded, 'Marker public transport decode mismatch'
    rows = [r for r in json.loads(decoded)['data'] if r['tip'] == 'Secde']
    assert len(rows) == 14
    pages = json.loads((ROOT / 'assets/data/pages.json').read_text())['items']
    items = [{'surah':r['sure_id'], 'ayah':r['ayet_no'], 'sourcePage':r['sayfa'], 'sourceMarkerId':r['id']} for r in rows]
    assert len({(r['surah'],r['ayah']) for r in items}) == len(items)
    for r in items:
        assert {'surah':r['surah'],'ayah':r['ayah']} in pages[r['sourcePage']]['verses']
    return {'source':{
        'url':'https://kuran.diyanet.gov.tr/api/v2/isaretciler',
        'readerUrl':'https://kuran.diyanet.gov.tr/kuran',
        'field':'data filtered by tip == Secde; sure_id/ayet_no retained exactly',
        'responsePath':str(raw_path.relative_to(ROOT)),
        'responseSha256':hashlib.sha256(raw).hexdigest(),
        'decodedPath':str(decoded_path.relative_to(ROOT)),
        'decodedSha256':hashlib.sha256(decoded).hexdigest(),
        'publicClientSha256':hashlib.sha256(client.read_bytes()).hexdigest(),
        'policy':'Diyanet portal marker positions, not a universal madhhab ruling. Some markers begin a multi-verse sajdah passage (e.g. 16:49, 17:107, 27:25, 41:37); do not silently replace these with later verses or infer markers from Arabic words. Annotation only; canonical scripture and grouped translations unchanged.'
    },'items':items}

def build():
    target = ROOT / 'assets/data/sajdah_markers.json'
    target.write_text(json.dumps(build_document(),ensure_ascii=False,indent=2)+'\n')
    print('PASS: 14 Diyanet sajdah positions derived; raw/decoded and source-page membership verified.')

if __name__ == '__main__':
    build()
