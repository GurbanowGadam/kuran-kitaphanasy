#!/usr/bin/env python3
"""Capture public Diyanet pages via the same transport decoder as its public SPA.
No authentication, challenge solving, or source-text normalization. Stop on HTTP errors.
Offline rebuilds use frozen responses; network refresh is explicit, not automatic.
"""
import base64
import datetime
import hashlib
import json
import re
import subprocess
import urllib.request
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/sources/diyanet-reading'
BASE = 'https://kuran.diyanet.gov.tr'
def fetch(url):
    with urllib.request.urlopen(url, timeout=40) as r:
        return r.read()
def sha(b):
    return hashlib.sha256(b).hexdigest()
def decode(raw, key):
    obj = json.loads(raw)
    return subprocess.run(['openssl', 'enc', '-d', '-aes-256-cbc', '-K', key,
                           '-iv', base64.b64decode(obj['iv']).hex()],
                          input=base64.b64decode(obj['data']), capture_output=True, check=True).stdout
if __name__ == '__main__':
    OUT.mkdir(exist_ok=True)
    html = fetch(BASE + '/')
    jsurl = BASE + re.search(rb'type="module" crossorigin src="([^"]+)', html)[1].decode()
    js = fetch(jsurl)
    # Public application transport key, not an account credential.
    key = re.search(rb'const \w+="([0-9a-f]{64})";let \w+=null;function', js)[1].decode()
    (OUT / 'public-client.js').write_bytes(js)
    (OUT / 'index.html').write_bytes(html)
    captures = []
    for page in range(10):
        url = f'{BASE}/api/v2/sayfa/{page}?font_id=173'
        raw = fetch(url)
        decoded = decode(raw, key)
        obj = json.loads(decoded)
        assert obj['meta']['count'] == len(obj['data'])
        for v in obj['data']:
            assert v['sayfa'] == page
            assert len([t for t in v['metinler'] if t['metin_grubu_id'] == 4]) == 1
        rawpath = OUT / f'page-{page:02}-response.json'
        path = OUT / f'page-{page:02}-decoded.json'
        rawpath.write_bytes(raw)
        path.write_bytes(decoded)
        captures.append({'url':url,'path':str(path.relative_to(ROOT)), 'sha256':sha(decoded),
                         'responsePath':str(rawpath.relative_to(ROOT)), 'responseSha256':sha(raw)})
        print(page, len(obj['data']), flush=True)
    manifest = {'retrievedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'publicClientUrl':jsurl,'publicClientSha256':sha(js),
                'transport':'Public SPA AES-256-CBC transport decoder; OpenSSL removes PKCS7 padding. JSON parsing only; no scripture edits.',
                'fontId':173,'textGroup':4,'captures':captures}
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
