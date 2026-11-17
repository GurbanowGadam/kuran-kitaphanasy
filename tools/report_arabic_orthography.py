#!/usr/bin/env python3
"""Exact codepoint comparison: rejected Uthmani capture vs restored Diyanet."""
import collections
import difflib
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def load(p):return json.loads((ROOT/p).read_text())
def cp(s):return ['U+%04X'%ord(c) for c in s]
old={}
for s,end in [(1,7),(2,69)]:
    for v in load(f'assets/sources/alquran-cloud-surah-{s}-uthmani.json')['data']['ayahs'][:end]:
        text=v['text'].lstrip('\ufeff')
        if s==2 and v['numberInSurah']==1:text=text[len(old[1,1])+1:]
        old[s,v['numberInSurah']]=text
new={}
for p in sorted((ROOT/'assets/sources/diyanet-reading').glob('*-decoded.json')):
    for v in json.loads(p.read_text())['data']:
        new[v['sure_id'],v['ayet_no']]=next(t['metin'] for t in v['metinler'] if t['metin_grubu_id']==4)
changes=[]
for key,b in new.items():
    a=old[key]
    edits=[{'operation':op,'oldRange':[i,j],'newRange':[k,l], 'old':a[i:j], 'new':b[k:l], 'oldCodepoints':cp(a[i:j]),'newCodepoints':cp(b[k:l])}
           for op,i,j,k,l in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes() if op!='equal']
    changes.append({'surah':key[0],'ayah':key[1],'old':a,'new':b,'edits':edits})
legacy=load('assets/sources/arabic-verified.json')
quran=load('assets/quran.json')
checks=[]
for s in quran['surahs']:
    for b in s['blocks']:
        if s['id'] in (1,2) and b['range'].isdigit():
            key=(s['id'],int(b['range']))
            checks.append({'surah':key[0],'ayah':key[1],'exact':new[key]==b['arabic']})
report={'summary':'Resmî Diyanet metin grubu 4 geri yüklendi; hiçbir harf/hareke normalizasyonu yapılmadı.',
        'changedVerses':sum(bool(v['edits']) for v in changes),
        'previousSharedExactMatches':sum(v['arabic']==new[v['surah'],v['ayah']] for v in legacy if (v['surah'],v['ayah']) in new),
        'legacyQuranChecks':checks,
        'codepointCounts':{name:{'U+%04X'%ord(c):n for c,n in sorted(collections.Counter(''.join(values)).items())} for name,values in [('rejectedUthmani',old.values()),('officialDiyanet',new.values())]},
        'preservedArtifactHashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'assets/data').glob('*.json')) if p.name!='verses.json'},
        'verses':changes}
p=ROOT/'assets/sources/orthography-diff.json'
p.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('Changed:',report['changedVerses'],'Legacy source exact:',report['previousSharedExactMatches'],'quran.json:',checks)
