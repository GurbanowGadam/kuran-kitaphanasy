#!/usr/bin/env python3
"""Resumable metadata-only discovery. Never downloads complete audio."""
import concurrent.futures as cf
import copy
import datetime as dt
import hashlib
import json
import pathlib
import re
import shutil
import time
import urllib.request

OLD = pathlib.Path('/home/gadamgurban/kuran-mp3quran-v0.0.1')
ROOT = pathlib.Path('/home/gadamgurban/kuran-mp3quran-v0.0.1-full')
META = pathlib.Path('/home/gadamgurban/kuran-kitaphanasy/assets/data/surah_metadata.json')

def sha(data): return hashlib.sha256(data).hexdigest()

def atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.tmp')
    temp.write_bytes(data)
    temp.replace(path)

def save(path, obj): atomic(path, (json.dumps(obj,ensure_ascii=False,indent=2)+'\n').encode())

def range_total(status, cr, data):
    match = re.fullmatch(r'bytes 0-511/(\d+)', cr or '')
    if status != 206 or not match or len(data) != 512 or int(match[1]) < 512:
        raise ValueError(f'invalid Range response: {status}, {cr}, {len(data)} bytes')
    return int(match[1])

def validate_rows(rows, expected):
    errors=[]
    unique=[]
    for row in rows:
        triple=(row['ayah'],row['start_time'],row['end_time'])
        if triple not in unique: unique.append(triple)
    positive=[x[0] for x in unique if x[0]>0]
    if positive != list(range(1,expected+1)): errors.append({'canonical_order_count':positive,'expected_count':expected})
    previous=None
    for ayah,start,end in unique:
        if start < 0 or end <= start: errors.append({'invalid_interval':[ayah,start,end]})
        if previous is not None and start < previous[2]: errors.append({'overlap':[previous,[ayah,start,end]]})
        previous=[ayah,start,end]
    return errors

def fetch(url, relative, audio=False):
    headers={'User-Agent':'KuranKitaphanasy-metadata-preflight/0.0.1','Accept-Encoding':'identity'}
    if audio: headers['Range']='bytes=0-511'
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url,headers=headers),timeout=25) as response:
                status=response.status
                # Even a server ignoring Range cannot cause a complete MP3 download.
                data=response.read(513 if audio else 4000000)
                info={'url':url,'final_url':response.url,'http_status':status,'content_type':response.headers.get('Content-Type'),'bytes_read':len(data),'sha256':sha(data),'raw_file':relative,'request':{'method':'GET','headers':headers},'response_headers':dict(response.headers),'retrieved_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'attempt':attempt+1}
                atomic(ROOT/relative,data)
                if audio:
                    info.update(content_range=response.headers.get('Content-Range'),content_length=response.headers.get('Content-Length'),etag=response.headers.get('ETag'),last_modified=response.headers.get('Last-Modified'),prefix_hex=data.hex())
                    info['total_bytes']=range_total(status,info['content_range'],data)
                    info['range_honored']=True
                elif status != 200: raise ValueError(f'timing HTTP {status}')
                return info,data
        except Exception:
            if attempt == 3: raise
            time.sleep(.25*(attempt+1))

def main():
    old=json.loads((OLD/'provenance/source-contract.json').read_text())
    contract=copy.deepcopy(old)
    contract['target_surahs']=list(range(1,115))
    counts={str(x['surah']):x['verseCount'] for x in json.loads(META.read_text())['items']}
    assert sorted(map(int,counts)) == list(range(1,115))
    assert [r['selected_moshaf']['id'] for r in old['reciters']] == [92,4,123,54,133]
    contract['expected_verse_counts']=counts
    contract['metadata_source']={'path':str(META),'sha256':sha(META.read_bytes())}
    contract['scope']='full 114 surahs x same five selected moshafs; metadata only'
    contract['verification']={str(r['selected_moshaf']['id']):{'timing':{},'audio':{},'soar':old['verification'][str(r['selected_moshaf']['id'])].get('soar',{})} for r in old['reciters']}
    contract['preflight_complete']=False
    for p in (OLD/'provenance').iterdir():
        if p.is_file() and p.name != 'source-contract.json' and p.suffix in ('.json','.html') and p.stat().st_size<3000000:
            dest=ROOT/'provenance'/p.name
            dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(p,dest)
    for p in (OLD/'provenance/timings').glob('soar-*.json'):
        dest=ROOT/'provenance/timings'/p.name
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(p,dest)
    save(ROOT/'provenance/source-contract.json',contract)
    def work(rec,surah):
        mid=rec['selected_moshaf']['id']; key=str(mid); sk=str(surah)
        checkpoint=ROOT/f'provenance/preflight-items/{mid}-{surah:03d}.json'
        if checkpoint.exists():
            cached=json.loads(checkpoint.read_text())
            try:
                for k in ('timing','audio'):
                    v=cached[k]; assert sha((ROOT/v['raw_file']).read_bytes())==v['sha256']
                range_total(cached['audio']['http_status'],cached['audio']['content_range'],(ROOT/cached['audio']['raw_file']).read_bytes())
                return cached
            except Exception: pass
        result={'moshaf_id':mid,'surah':surah,'errors':[]}
        try:
            previous=old['verification'][key]['timing'].get(sk)
            if previous and sha((OLD/previous['raw_file']).read_bytes())==previous['sha256']:
                raw=(OLD/previous['raw_file']).read_bytes(); timing=copy.deepcopy(previous)
                atomic(ROOT/timing['raw_file'],raw)
                timing['reused_hash_verified_from']=str(OLD/previous['raw_file'])
            else:
                timing,raw=fetch(contract['timing_template'].format(surah=surah,moshaf_id=mid),f'provenance/timings/timing-{mid}-{surah:03d}.json')
            rows=json.loads(raw)
            timing['rows']=rows
            timing['expected_verse_count']=counts[sk]
            timing['metadata_validation_errors']=validate_rows(rows,counts[sk])
            timing['all_verses_present']=set(r['ayah'] for r in rows if r['ayah']>0)==set(range(1,counts[sk]+1))
            timing['last_end_ms']=max((r['end_time'] for r in rows),default=None)
            result['timing']=timing
            result['errors'].extend(timing['metadata_validation_errors'])
            save(checkpoint,result)
            # Original contract stores only 16 prefix bytes: obtain complete evidence afresh.
            audio,raw=fetch(rec['selected_moshaf']['server']+f'{surah:03d}.mp3',f'provenance/audio-prefixes/{mid}-{surah:03d}.bin',True)
            result['audio']=audio
        except Exception as exc: result['errors'].append({'fetch_error':str(exc)})
        save(checkpoint,result)
        return result
    results=[]
    with cf.ThreadPoolExecutor(max_workers=4) as pool:
        futures=[pool.submit(work,r,s) for r in contract['reciters'] for s in range(1,115)]
        for future in cf.as_completed(futures):
            result=future.result(); results.append(result)
            for kind in ('timing','audio'):
                if kind in result: contract['verification'][str(result['moshaf_id'])][kind][str(result['surah'])]=result[kind]
            if len(results)%25==0:
                save(ROOT/'provenance/source-contract.json',contract)
                print(f'metadata pairs {len(results)}/570',flush=True)
    totals={str(r['selected_moshaf']['id']):0 for r in contract['reciters']}
    sizes=[]
    for result in results:
        if 'audio' in result:
            n=result['audio']['total_bytes']; totals[str(result['moshaf_id'])]+=n
            sizes.append((n,result['moshaf_id'],result['surah']))
    errors=[{'moshaf_id':x['moshaf_id'],'surah':x['surah'],'errors':x['errors']} for x in results if x['errors']]
    complete=sum('timing' in x and 'audio' in x for x in results)
    manifest={'scope':'metadata-only; no complete audio downloaded','expected_pairs':570,'metadata_pairs_complete':complete,'timing_count':sum('timing' in x for x in results),'range_evidence_count':len(sizes),'error_pair_count':len(errors),'errors':errors,'measured_audio_bytes_total':sum(totals.values()),'measured_audio_bytes_per_moshaf':totals,'largest_source_mp3':dict(zip(('bytes','moshaf_id','surah'),max(sizes))) if sizes else None,'max_zip_bytes':None,'max_zip_note':'Not measurable before actual archive build; source MP3 sizes above are exact HTTP Content-Range totals, not ZIP size estimates.','audio_duration_validation':'pending real full-file ffprobe on remote server','remote_audio_root':'panda@192.168.1.138:/home/panda/kuran-mp3quran-v0.0.1-full','pool_workers':4,'timeout_seconds':25,'retries':3,'completed_at_utc':dt.datetime.now(dt.timezone.utc).isoformat()}
    contract['preflight_complete']=complete==570
    contract['metadata_validation_passed']=not errors
    contract['preflight_manifest']='provenance/preflight-manifest.json'
    save(ROOT/'provenance/source-contract.json',contract)
    save(ROOT/'provenance/preflight-manifest.json',manifest)
    save(ROOT/'manifest-preflight.json',manifest)
    print(json.dumps({k:v for k,v in manifest.items() if k!='errors'},ensure_ascii=False),flush=True)

if __name__=='__main__': main()
