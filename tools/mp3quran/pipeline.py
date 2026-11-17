"""MP3Quran full-surah-timed-v1 builder. Standard library + ffprobe only."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import urllib.request
import zipfile

MAX_AUDIO = 128 * 1024 * 1024
NAMES = {92:'Ýasir ed-Dewseri',4:'Ebu Bekir eş-Şatri',123:'Mişari Raşid el-Afasi',54:'Abdurrahman es-Sudeýs',133:'Mahir el-Muaiqly'}

def dump(path, obj):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.writing')
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    tmp.replace(path)

def sha256(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''): h.update(block)
    return h.hexdigest()

def verify_digest(path, size, digest):
    if Path(path).stat().st_size != size or sha256(path) != digest:
        raise ValueError('byte length or SHA256 mismatch: '+str(path))

def validate_binding(reciter):
    m=reciter['selected_moshaf']; t=reciter['timing_read']
    if m['id'] != t['id'] or m['server'] != t['folder_url'] or not m['server'].startswith('https://cdn.mp3quran.net/audio/'):
        raise ValueError('moshaf/read source binding mismatch')

def validate_timings(rows, count, duration):
    if type(duration) is not int or duration <= 0: raise ValueError('invalid duration')
    result=[]; prev=-1; previous_end=0
    for row in rows:
        a,s,e=row['ayah'],row['start_time'],row['end_time']
        if (any(type(x) is not int for x in (a,s,e)) or not 0 <= s < duration
                or s >= e or e > duration + (500 if a == count else 0)):
            raise ValueError(f'out-of-range/noninteger original interval: {row}; durationMs={duration}')
        if a < 0 or a <= prev or s < previous_end: raise ValueError('duplicate/unordered/overlapping original timing')
        prev=a;previous_end=e
        if a > 0: result.append({'ayah':a,'startMs':s,'endMs':e})
    if [r['ayah'] for r in result] != list(range(1,count+1)): raise ValueError('incomplete canonical coverage')
    return result

TIMING_POLICY = 'original-starts-eof-500ms-v1'

def validate_timing_policy(package):
    delta=max(0,package['verseTimings'][-1]['endMs']-package['totalDurationMs'])
    source=package['source']
    if (source.get('timingPolicy')!=TIMING_POLICY or
            type(source.get('timingEndBeyondAudioMs')) is not int or
            source['timingEndBeyondAudioMs']!=delta):
        raise ValueError('timing policy/warning declaration mismatch')
    return delta

def timing_warnings(records):
    return [{'path':r['path'],'timingEndBeyondAudioMs':validate_timing_policy(r['package']),
             'originalEndMs':r['package']['verseTimings'][-1]['endMs'],
             'actualDurationMs':r['package']['totalDurationMs']}
            for r in records if validate_timing_policy(r['package'])>0]

def checksums(root):
    root=Path(root)
    (root/'SHA256SUMS').write_text(''.join(f'{sha256(p)}  {p.relative_to(root).as_posix()}\n' for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256SUMS'))

def package_audio(audio, target):
    audio=Path(audio);target=Path(target)
    if audio.stat().st_size > MAX_AUDIO: raise ValueError('MP3 exceeds 128MiB')
    target.parent.mkdir(parents=True,exist_ok=True)
    temporary=target.with_suffix('.zip.part')
    info=zipfile.ZipInfo(audio.name,(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_STORED
    info.create_system=3;info.external_attr=0o100644 << 16
    try:
        with zipfile.ZipFile(temporary,'w',compression=zipfile.ZIP_STORED,allowZip64=False) as z:
            with z.open(info,'w') as out, audio.open('rb') as source: shutil.copyfileobj(source,out,1024*1024)
        if temporary.stat().st_size > MAX_AUDIO: raise ValueError('ZIP exceeds 128MiB')
        with zipfile.ZipFile(temporary) as z:
            if z.namelist()!=[audio.name] or z.testzip(): raise ValueError('ZIP integrity failed')
            with z.open(audio.name) as f:
                h=hashlib.file_digest(f,'sha256').hexdigest()
            if h!=sha256(audio): raise ValueError('ZIP changed original source bytes')
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)

def download(url, target, expected=None, max_bytes=MAX_AUDIO):
    target=Path(target);target.parent.mkdir(parents=True,exist_ok=True)
    for attempt in range(3):
        try:
            req=urllib.request.Request(url,headers={'User-Agent':'KuranKitaphanasy/0.0.1 source-verifier','Accept-Encoding':'identity'})
            with urllib.request.urlopen(req,timeout=90) as response, target.open('wb') as out:
                if response.status != 200: raise ValueError(f'expected complete HTTP200, got {response.status}: {url}')
                size=0
                while block:=response.read(256*1024):
                    size+=len(block)
                    if size>max_bytes: raise ValueError('download exceeds bounded size')
                    out.write(block)
                if expected is not None and size!=expected: raise ValueError(f'source length changed: {size} != {expected}')
                out.flush()
                os.fsync(out.fileno())
                return {'requestedUrl':url,'finalUrl':response.url,'status':response.status,'contentType':response.headers.get('Content-Type'),'etag':response.headers.get('ETag'),'lastModified':response.headers.get('Last-Modified'),'bytes':size,'sha256':sha256(target)}
        except Exception:
            target.unlink(missing_ok=True)
            if attempt==2: raise
            time.sleep(attempt+1)

def measure(audio):
    raw=subprocess.check_output(['ffprobe','-v','error','-select_streams','a:0','-show_entries','stream=codec_name,bit_rate,duration:format=duration','-of','json',str(audio)])
    obj=json.loads(raw)
    if not obj['streams'] or obj['streams'][0]['codec_name']!='mp3': raise ValueError('not MP3 audio')
    duration=round(float(obj['format']['duration'])*1000)
    return duration, round(int(obj['streams'][0]['bit_rate'])/1000), obj

def package_path(package):
    return f"packages/{package['reciterId']}/{package['surah']:03d}.zip"

def validate_map(catalog, mapping, old_ids):
    def valid(value): return isinstance(value,str) and re.fullmatch(r'[A-Za-z0-9_-]{10,}',value) and value not in old_ids
    if mapping.get('contentVersion')!=catalog['contentVersion'] or not valid(mapping.get('driveFolderId')): raise ValueError('missing/new folder ID required')
    expected={package_path(p) for p in catalog['packages']};seen=set();ids=set()
    for item in mapping['files']:
        path=item['path'];fid=item['driveFileId']
        if path not in expected or path in seen or not valid(fid) or fid in ids or fid==mapping['driveFolderId']: raise ValueError('missing/duplicate/old/invalid map ID or path')
        seen.add(path);ids.add(fid)
    if seen!=expected: raise ValueError('map must cover all packages exactly')

def build(root):
    root=Path(root).resolve();prov=root/'provenance'
    contract=json.loads((prov/'source-contract.json').read_text())
    jobs=[]
    for r in contract['reciters']:
        validate_binding(r)
        mid=r['selected_moshaf']['id']
        for surah in contract['target_surahs']:
            ev=contract['verification'][str(mid)]
            size=int(ev['audio'][str(surah)]['content_range'].split('/')[-1])
            timing=prov/'timings'/f'timing-{mid}-{surah:03d}.json'
            if sha256(timing)!=ev['timing'][str(surah)]['sha256']: raise ValueError('timing capture hash mismatch')
            jobs.append((r,surah,size,timing))
    total=sum(j[2] for j in jobs);peak=total+sum(sorted([j[2] for j in jobs],reverse=True)[:3])*2+20*1024*1024
    free=shutil.disk_usage(root).free
    dump(root/'preflight.json',{'sourceBytes':total,'conservativePeakAdditionalBytes':peak,'freeBytes':free,'workers':3,'perReciterBytes':{str(r['selected_moshaf']['id']):sum(j[2] for j in jobs if j[0]==r) for r in contract['reciters']}})
    if free<peak: raise ValueError('insufficient disk space')
    catalog={'version':2,'provider':'mp3quran','contentVersion':'0.0.1','driveFolderId':None,'reciters':[],'packages':[]}
    for r in contract['reciters']:
        mid=r['selected_moshaf']['id']
        catalog['reciters'].append({'id':f'mp3quran_{mid}','name':NAMES[mid],'bitrate':96 if mid==133 else 128,'sourceReciterId':r['reciter_id'],'moshafId':mid,'style':'Mojawwad' if mid==133 else 'Murattal'})
    def process(job):
        r,surah,size,timing=job;mid=r['selected_moshaf']['id'];rid=f'mp3quran_{mid}'
        url=r['selected_moshaf']['server']+f'{surah:03d}.mp3'
        package={'reciterId':rid,'surah':surah,'ayahCount':contract['expected_verse_counts'][str(surah)],'format':'full-surah-timed-v1','publicationStatus':'pending-upload','driveFileId':None,'audioFile':f'{surah:03d}.mp3'}
        with tempfile.TemporaryDirectory(prefix='mp3quran-',dir=root) as scratch:
            audio=Path(scratch)/package['audioFile']
            evidence=download(url,audio,size)
            duration,bitrate,probe=measure(audio)
            validation_error=None
            try: timings=validate_timings(json.loads(timing.read_text()),package['ayahCount'],duration)
            except ValueError as exc:
                validation_error=str(exc)
                timings=None
                dump(prov/f'FAILED-{mid}-{surah:03d}.json',{'error':str(exc),'download':evidence,'ffprobe':probe})
            package.update({'totalDurationMs':duration,'verseTimings':timings,'files':{audio.name:sha256(audio)},'source':{'provider':'mp3quran','url':url,'reciterId':r['reciter_id'],'moshafId':mid,'timingUrl':contract['timing_template'].format(surah=surah,moshaf_id=mid),'timingSha256':sha256(timing),'recordingStyle':'Mojawwad' if mid==133 else 'Murattal'}})
            if timings is not None:
                package['source'].update({'timingPolicy':TIMING_POLICY,'timingEndBeyondAudioMs':max(0,timings[-1]['endMs']-duration)})
            target=root/package_path(package)
            package_audio(audio,target)
            package.update({'bytes':target.stat().st_size,'sha256':sha256(target)})
            record={'path':package_path(package),'validationError':validation_error,'audioBytes':size,'measuredBitrateKbps':bitrate,'download':evidence,'ffprobe':probe,'timingCapture':str(timing.relative_to(root)),'package':package}
            dump(prov/'packages'/f'{mid}-{surah:03d}.json',record)
            print(f'{"BLOCKED" if validation_error else "OK"} {rid}/{surah:03d}: {size} source bytes, {duration} ms',flush=True)
            return record
    records=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        for record in executor.map(process,jobs): records.append(record)
    catalog['packages']=[r['package'] for r in records]
    for rec in catalog['reciters']:
        actual={r['measuredBitrateKbps'] for r in records if r['package']['reciterId']==rec['id']}
        # Recording bitrate is measured per package; nominal reciter field is
        # the common value, never a claim that every recording is identical.
        rec['bitrate']=max(actual, key=lambda b:sum(r['measuredBitrateKbps']==b and r['package']['reciterId']==rec['id'] for r in records))
        rec['measuredBitratesKbps']=sorted(actual)
        for record in records:
            if record['package']['reciterId']==rec['id']:
                record['package']['bitrate']=record['measuredBitrateKbps']
                dump(prov/'packages'/f"{record['package']['source']['moshafId']}-{record['package']['surah']:03d}.json",record)
    dump(root/'manifest.json',{'format':'full-surah-timed-v1','contentVersion':'0.0.1','packages':records})
    dump(root/'upload-map.template.json',{'contentVersion':'0.0.1','driveFolderId':None,'files':[{'path':package_path(p),'driveFileId':None} for p in catalog['packages']]})
    failures=[{'path':r['path'],'error':r['validationError']} for r in records if r['validationError']]
    summary={'status':'blocked-source-timing' if failures else 'verified-local-pending-upload','timingFailures':failures,'packages':len(records),'sourceMP3s':len(records),'sourceBytes':total,'zipBytes':sum(p['bytes'] for p in catalog['packages']),'canonicalTimingRows':sum(p['ayahCount'] for p in catalog['packages']),'remoteVerified':False,'auditoryAlignmentVerified':False,'unmodified':True,'workers':3}
    summary['sourceTimingWarnings']=timing_warnings([r for r in records if not r['validationError']])
    dump(root/'verification-summary.json',summary)
    if not failures: dump(root/'audio_catalog.candidate.json',catalog)
    (root/'SHA256SUMS').write_text(''.join(f'{sha256(p)}  {p.relative_to(root).as_posix()}\n' for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256SUMS'))
    print(json.dumps(summary),flush=True)
    require_valid_release(records)

def require_valid_release(records):
    if any(r.get('validationError') for r in records):
        raise ValueError('release blocked by original source timing errors; see verification-summary.json; no runtime candidate emitted')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--root',required=True)
    build(parser.parse_args().root)
