"""Offline metadata refresh: existing ZIPs and frozen provenance only; never downloads or repacks."""
import argparse
import json
from pathlib import Path
import shutil
import tempfile
import zipfile
from pipeline import (NAMES, TIMING_POLICY, checksums, dump, measure, sha256,
                      timing_warnings, validate_timings, verify_digest)
from import_drivemap import audit


def refresh(root):
    root=Path(root).resolve()
    manifest=json.loads((root/'manifest.json').read_text())
    contract=json.loads((root/'provenance/source-contract.json').read_text())
    records=manifest['packages']
    reciters=[]
    for r in contract['reciters']:
        mid=r['selected_moshaf']['id']
        reciters.append({'id':f'mp3quran_{mid}','name':NAMES[mid],'sourceReciterId':r['reciter_id'],'moshafId':mid,'style':'Mojawwad' if mid==133 else 'Murattal'})
    for record in records:
        p=record['package']; mid=p['source']['moshafId']; s=p['surah']
        target=root/record['path']
        verify_digest(target,p['bytes'],p['sha256'])
        timing=root/'provenance/timings'/f'timing-{mid}-{s:03d}.json'
        if sha256(timing)!=p['source']['timingSha256'] or sha256(timing)!=contract['verification'][str(mid)]['timing'][str(s)]['sha256']:
            raise ValueError('raw timing hash mismatch')
        with tempfile.TemporaryDirectory(prefix='mp3quran-refresh-') as scratch, zipfile.ZipFile(target) as z:
            if z.namelist()!=[p['audioFile']]: raise ValueError('unexpected ZIP members')
            audio=Path(scratch)/p['audioFile']
            with z.open(p['audioFile']) as src,audio.open('wb') as out: shutil.copyfileobj(src,out)
            if sha256(audio)!=p['files'][p['audioFile']] or sha256(audio)!=record['download']['sha256']: raise ValueError('original source hash mismatch')
            duration,bitrate,probe=measure(audio)
            if duration!=p['totalDurationMs']: raise ValueError('duration changed')
            p['verseTimings']=validate_timings(json.loads(timing.read_text()),p['ayahCount'],duration)
            p['source']['timingPolicy']=TIMING_POLICY
            p['source']['timingEndBeyondAudioMs']=max(0,p['verseTimings'][-1]['endMs']-duration)
            p['bitrate']=bitrate
            record['ffprobe']=probe; record['measuredBitrateKbps']=bitrate
            if record.get('validationError'): record['supersededValidationError']=record['validationError']
            record['validationError']=None
    for rec in reciters:
        rates=[r['measuredBitrateKbps'] for r in records if r['package']['reciterId']==rec['id']]
        rec['bitrate']=max(sorted(set(rates)),key=rates.count)
        rec['measuredBitratesKbps']=sorted(set(rates))
    catalog={'version':2,'provider':'mp3quran','contentVersion':'0.0.1','driveFolderId':None,'reciters':reciters,'packages':[r['package'] for r in records]}
    dump(root/'manifest.json',manifest)
    for record in records:
        p=record['package']
        dump(root/'provenance/packages'/f"{p['source']['moshafId']}-{p['surah']:03d}.json",record)
    for old in (root/'provenance').glob('FAILED-*.json'):
        obj=json.loads(old.read_text());obj['historicalStatus']='superseded by original-starts-eof-500ms-v1; retained as evidence, not a current failure';dump(old,obj)
    dump(root/'audio_catalog.candidate.json',catalog)
    dump(root/'upload-map.template.json',{'contentVersion':'0.0.1','driveFolderId':None,'files':[{'path':r['path'],'driveFileId':None} for r in records]})
    summary={'status':'verified-local-pending-upload','timingFailures':[],'sourceTimingWarnings':timing_warnings(records),'packages':len(records),'sourceMP3s':len(records),'sourceBytes':sum(r['audioBytes'] for r in records),'zipBytes':sum(r['package']['bytes'] for r in records),'canonicalTimingRows':sum(r['package']['ayahCount'] for r in records),'remoteVerified':False,'auditoryAlignmentVerified':False,'unmodified':True,'refreshMode':'offline-existing-zips'}
    dump(root/'verification-summary.json',summary)
    _,errors=audit(root)
    if errors: raise ValueError(errors)
    checksums(root)
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',required=True)
    refresh(parser.parse_args().root)
