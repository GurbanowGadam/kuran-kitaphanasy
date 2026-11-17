#!/usr/bin/env python3
"""Measure verified original archive bytes; only add durationsMs to catalog.
Usage: python3 tools/measure_audio_timings.py [archive-root]
"""
import concurrent.futures
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

catalog_path = Path(__file__).resolve().parents[1] / 'assets/data/audio_catalog.json'
root = Path(sys.argv[1] if len(sys.argv) > 1 else '/home/gadamgurban/kuran-audio-drive-test')
catalog = json.loads(catalog_path.read_text())

def measure(p):
    candidates = list((root / p['reciterId']).rglob(f"{p['surah']:03d}_*.zip"))
    if len(candidates) != 1:
        raise ValueError(f"Expected one archive: {p['reciterId']}/{p['surah']}: {candidates}")
    archive = candidates[0].read_bytes()
    assert len(archive) == p['bytes']
    assert hashlib.sha256(archive).hexdigest() == p['sha256']
    result = {}
    with zipfile.ZipFile(candidates[0]) as z, tempfile.TemporaryDirectory() as tmp:
        for name, expected in p['files'].items():
            data = z.read(name)
            assert hashlib.sha256(data).hexdigest() == expected, name
            path = Path(tmp) / name
            path.write_bytes(data)
            output = subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', str(path)], text=True).strip()
            seconds = Decimal(output)
            assert seconds.is_finite() and seconds > 0, (name, output)
            ms = int((seconds * 1000).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
            assert ms > 0
            result[name] = ms
    print(f"Verified and measured {p['reciterId']}/{p['surah']}: {len(result)} files", flush=True)
    return result

with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
    results = list(pool.map(measure, catalog['packages']))
for p, timing in zip(catalog['packages'], results):
    p['durationsMs'] = timing
catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
print(f"SUCCESS: {len(results)} packages, {sum(map(len, results))} exact verified MP3 durations; metadata only")
