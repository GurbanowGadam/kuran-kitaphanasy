#!/usr/bin/env python3
"""Rebuild twice offline and compare every manifest artifact plus manifest bytes."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
    manifest=ROOT/'assets/sources/full-content-manifest.json'
    paths=list(json.loads(manifest.read_text())['artifactHashes'])+['assets/sources/full-content-manifest.json']
    return {p:sha(ROOT/p) for p in sorted(paths)}

def main():
    runs=[];before=snapshot()
    for n in (1,2):
        result=subprocess.run([sys.executable,str(ROOT/'tools/build_full_content.py')],cwd=ROOT,capture_output=True,text=True)
        print(f'BUILD {n}: exit={result.returncode}\n{result.stdout}',end='',flush=True)
        if result.stderr:print(result.stderr,end='',file=sys.stderr)
        result.check_returncode()
        runs.append({'build':n,'exitCode':result.returncode,'stdout':result.stdout,'stderr':result.stderr,'hashes':snapshot()})
    differences=[p for p in runs[0]['hashes'] if runs[0]['hashes'][p]!=runs[1]['hashes'][p]]
    report={'method':'Two consecutive complete offline rebuilds; SHA-256 compared for every manifest artifact and the manifest itself. Reports contain no current timestamp. This does not compare UI/platform build outputs.',
            'python':sys.version,'executable':sys.executable,'builds':runs,'differentPaths':differences,
            'changedFromPrecheck':[p for p in before if before[p]!=runs[1]['hashes'][p]]}
    path=ROOT/'assets/sources/full-content-reproducibility.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    assert not differences,differences
    print(f'PASS: two builds byte-identical across {len(runs[0]["hashes"])} artifacts including manifest.')

if __name__=='__main__':main()
