"""Full 5 x 114 expansion; verified archives local (--local) or remote SSH.

No mass download at import. Run --help for the explicit production entry point.
The 128 MiB pipeline/app ceiling and original 500 ms EOF policy are unchanged.
"""
import argparse
import concurrent.futures
import copy
import hashlib
import json
import os
import shutil
from pathlib import Path, PurePosixPath
import re
import shlex
import subprocess
import tempfile
import uuid
import zipfile

try:
    from . import pipeline as p
except ImportError:
    import pipeline as p


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def validate_contract(contract):
    if contract.get('target_surahs') != list(range(1, 115)):
        raise ValueError('contract must cover all 114 surahs in order')
    reciters = contract.get('reciters', [])
    if len(reciters) != 5 or {r['selected_moshaf']['id'] for r in reciters} != set(p.NAMES):
        raise ValueError('contract must contain exactly the original five moshafs')
    counts = contract['expected_verse_counts']
    if set(counts) != {str(s) for s in range(1, 115)} or any(type(v) is not int or v <= 0 for v in counts.values()):
        raise ValueError('missing/invalid source canonical verse counts')
    if sum(counts.values()) != 6236:
        raise ValueError('source canonical counts do not total 6236')
    for r in reciters:
        p.validate_binding(r)


def make_job(root, contract, reciter, surah):
    mid = reciter['selected_moshaf']['id']
    ev = contract['verification'][str(mid)]
    audio = ev['audio'][str(surah)]
    match = re.fullmatch(r'bytes 0-511/(\d+)', audio['content_range'])
    if not match or audio['bytes_read'] != 512:
        raise ValueError('complete 512-byte range evidence required')
    size = int(match.group(1))
    # Do not increase either app/pipeline bound implicitly, including ZIP overhead.
    if size + 112 > p.MAX_AUDIO:
        raise ValueError(f'{mid}/{surah:03d}: source needs size-limit approval: {size} bytes')
    timing = Path(root)/'provenance/timings'/f'timing-{mid}-{surah:03d}.json'
    digest = ev['timing'][str(surah)]['sha256']
    if p.sha256(timing) != digest:
        raise ValueError('timing capture hash mismatch: ' + str(timing))
    return {'mid':mid, 'surah':surah, 'count':contract['expected_verse_counts'][str(surah)],
            'reciter':reciter, 'url':reciter['selected_moshaf']['server']+f'{surah:03d}.mp3',
            'size':size, 'audio_evidence':audio, 'timing':timing, 'timing_sha256':digest}


def verify_head(url, expected, opener=p.urllib.request.urlopen):
    request=p.urllib.request.Request(url,method='HEAD',headers={'Accept-Encoding':'identity','User-Agent':'KuranKitaphanasy/0.0.1 source-verifier'})
    with opener(request,timeout=90) as response:
        if response.status != 200 or int(response.headers.get('Content-Length','-1')) != expected:
            raise ValueError('HEAD source length/status mismatch')


def verify_source(audio, evidence):
    size = int(evidence['content_range'].split('/')[-1])
    if Path(audio).stat().st_size != size or evidence['bytes_read'] != 512:
        raise ValueError('source length/range evidence mismatch')
    with open(audio, 'rb') as f:
        digest = hashlib.sha256(f.read(512)).hexdigest()
    if digest != evidence['sha256']:
        raise ValueError('complete source 512-byte prefix SHA256 mismatch')
    # Some captures include a separate HEAD observation; both must agree.
    head = evidence.get('head', evidence.get('head_probe', {}))
    head_size = head.get('content_length', head.get('contentLength'))
    if head_size is not None and int(head_size) != size:
        raise ValueError('HEAD source length mismatch')


def guard_record(record, job):
    package = record['package']
    if (package['reciterId'] != f"mp3quran_{job['mid']}" or package['surah'] != job['surah']
            or package['ayahCount'] != job['count'] or package['format'] != 'full-surah-timed-v1'
            or package['audioFile'] != f"{job['surah']:03d}.mp3"
            or record['path'] != p.package_path(package)
            or record['audioBytes'] != job['size'] or record['download']['bytes'] != job['size']
            or package['source']['url'] != job['url']
            or package['source']['timingSha256'] != job['timing_sha256']):
        raise ValueError('reused record differs from current source contract')


def verify_archive(archive, record):
    package = record['package']
    p.verify_digest(archive, package['bytes'], package['sha256'])
    with zipfile.ZipFile(archive) as z:
        if z.namelist() != [package['audioFile']] or z.testzip():
            raise ValueError('unsafe or invalid original ZIP')
        info = z.getinfo(package['audioFile'])
        if info.file_size != record['audioBytes'] or info.file_size > p.MAX_AUDIO:
            raise ValueError('invalid archived audio size')
        with z.open(info) as f:
            digest = hashlib.file_digest(f, 'sha256').hexdigest()
        if digest != package['files'][package['audioFile']] or digest != record['download']['sha256']:
            raise ValueError('archived audio SHA256 mismatch')


class LocalPublisher:
    def __init__(self, root):
        self.root = Path(root).resolve()

    def path(self, relative):
        if not re.fullmatch(r'packages/[A-Za-z0-9_-]+/\d{3}\.zip', relative):
            raise ValueError('unsafe archive relative path')
        target = self.root / relative
        if not target.resolve().is_relative_to(self.root):
            raise ValueError('archive path escapes local root')
        return target

    def matches(self, relative, size, digest):
        target = self.path(relative)
        return target.is_file() and target.stat().st_size == size and p.sha256(target) == digest

    def publish(self, local, relative, size, digest):
        p.verify_digest(local, size, digest)
        target = self.path(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        fd, name = tempfile.mkstemp(prefix=target.name+'.part-', dir=target.parent)
        os.close(fd)
        stage = Path(name)
        try:
            shutil.copyfile(local, stage)
            p.verify_digest(stage, size, digest)
            with stage.open('rb') as f:
                os.fsync(f.fileno())
            os.replace(stage, target)
            fd = os.open(str(target.parent), os.O_RDONLY)
            try: os.fsync(fd)
            finally: os.close(fd)
        finally:
            stage.unlink(missing_ok=True)


def storage_summary(local, verified):
    return {'archiveStorage': 'local' if local else 'remote', 'storageVerified': verified,
            'remoteVerified': verified and not local, 'driveVerified': False,
            'archiveTransport': 'filesystem' if local else 'SSH'}


class RemotePublisher:
    """SCP to unique staging; one remote Python process verifies then fsync/rename."""
    def __init__(self, remote, root, run=subprocess.run):
        if not re.fullmatch(r'[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+', remote):
            raise ValueError('expected user@host')
        if not re.fullmatch(r'/[A-Za-z0-9_./-]+', root) or '..' in PurePosixPath(root).parts:
            raise ValueError('unsafe absolute remote root')
        self.remote, self.root, self.run = remote, root.rstrip('/'), run

    def script(self, script):
        return self.run(['ssh','-oBatchMode=yes','-oConnectTimeout=15',self.remote,'python3 -'],
                        input=script, text=True, capture_output=True, check=True, timeout=180)

    def path(self, relative):
        if not re.fullmatch(r'packages/[A-Za-z0-9_-]+/\d{3}\.zip', relative):
            raise ValueError('unsafe archive relative path')
        return self.root+'/'+relative

    def matches(self, relative, size, digest):
        target=self.path(relative)
        result=self.script(f"import pathlib,hashlib\np=pathlib.Path({target!r})\nprint('MATCH' if p.is_file() and p.stat().st_size=={size!r} and hashlib.file_digest(p.open('rb'),'sha256').hexdigest()=={digest!r} else 'MISSING')\n")
        return result.stdout.strip() == 'MATCH'

    def publish(self, local, relative, size, digest):
        p.verify_digest(local, size, digest)
        target=self.path(relative); stage=target+'.part-'+uuid.uuid4().hex
        self.script(f"from pathlib import Path\nPath({target!r}).parent.mkdir(parents=True,exist_ok=True)\n")
        self.run(['scp','-q','-oBatchMode=yes','-oConnectTimeout=15',str(local),self.remote+':'+stage],
                 check=True, capture_output=True, text=True, timeout=600)
        self.script(f"""import os,hashlib,pathlib
stage=pathlib.Path({stage!r})
target=pathlib.Path({target!r})
size=stage.stat().st_size
with stage.open('rb') as f:
    digest=hashlib.file_digest(f,'sha256').hexdigest()
    if size != {size!r} or digest != {digest!r}:
        raise ValueError('remote staging size/SHA256 mismatch; no rename')
    os.fsync(f.fileno())
os.replace(stage,target)
fd=os.open(str(target.parent),os.O_RDONLY)
try: os.fsync(fd)
finally: os.close(fd)
print('MATCH')
""")


def validate_coverage(records, contract):
    expected={(f"mp3quran_{r['selected_moshaf']['id']}",s) for r in contract['reciters'] for s in contract['target_surahs']}
    actual=[(r['package']['reciterId'],r['package']['surah']) for r in records]
    if len(expected) != 570 or len(actual) != 570 or set(actual) != expected:
        raise ValueError('release requires exactly 5 x 114 = 570 unique packages')
    if sum(r['package']['ayahCount'] for r in records) != sum(contract['expected_verse_counts'].values())*5:
        raise ValueError('canonical row count mismatch')


def release_gate(root, records, contract):
    candidate=Path(root)/'audio_catalog.candidate.json'
    candidate.unlink(missing_ok=True)
    p.require_valid_release(records)
    validate_coverage(records, contract)


def validate_record_timings(record, job):
    if not record.get('validationError'):
        package=record['package']
        rows=p.validate_timings(load(job['timing']), job['count'], package['totalDurationMs'])
        if rows != package['verseTimings']:
            raise ValueError('reused timing metadata differs from captured original')
        p.validate_timing_policy(package)


def build(root, existing_root, remote=None, remote_root=None, workers=2, *, local=False):
    root=Path(root).resolve(); existing_root=Path(existing_root).resolve()
    if root == existing_root or existing_root in root.parents:
        raise ValueError('existing root is immutable; use separate full root')
    if not 1 <= workers <= 2:
        raise ValueError('workers must be 1 or 2 to bound RAM temporary storage')
    (root/'audio_catalog.candidate.json').unlink(missing_ok=True)
    contract=load(root/'provenance/source-contract.json')
    validate_contract(contract)
    jobs=[make_job(root,contract,r,s) for r in contract['reciters'] for s in contract['target_surahs']]
    publisher=LocalPublisher(root) if local else RemotePublisher(remote, remote_root)
    # Preflight every capture before the first network transfer.
    p.dump(root/'preflight.json', {'packages':len(jobs),'workers':workers,'sourceBytes':sum(j['size'] for j in jobs),
        'temporaryDirectory':'/tmp','maxAudioBytes':p.MAX_AUDIO,'remote':remote,'remoteRoot':remote_root,
        'peakTemporaryBytesUpperBound':workers*p.MAX_AUDIO*2,'localArchiveRetention':local,
        'archiveStorage':'local' if local else 'remote'})

    def process(job):
        mid,surah=job['mid'],job['surah']
        verify_head(job['url'],job['size'])
        record_path=root/'provenance/packages'/f'{mid}-{surah:03d}.json'
        old_path=existing_root/'provenance/packages'/record_path.name
        record=None
        if record_path.exists(): record=load(record_path)
        elif old_path.exists(): record=load(old_path)
        if record is not None:
            guard_record(record,job)
            validate_record_timings(record,job)
            package=record['package']
            if publisher.matches(record['path'],package['bytes'],package['sha256']):
                p.dump(record_path,record)
                return record,'resumed'
            archive=existing_root/record['path']
            if archive.exists():
                verify_archive(archive,record)
                # Compare original source prefix directly without extracting to local disk.
                with zipfile.ZipFile(archive) as z, z.open(package['audioFile']) as f:
                    if hashlib.sha256(f.read(512)).hexdigest() != job['audio_evidence']['sha256']:
                        raise ValueError('original ZIP source prefix differs from contract')
                publisher.publish(archive,record['path'],package['bytes'],package['sha256'])
                p.dump(record_path,record)
                return record,'reused'
        with tempfile.TemporaryDirectory(prefix=f'mp3quran-{mid}-{surah:03d}-',dir='/tmp') as scratch:
            audio=Path(scratch)/f'{surah:03d}.mp3'
            evidence=p.download(job['url'],audio,job['size'])
            verify_source(audio,job['audio_evidence'])
            duration,bitrate,probe=p.measure(audio)
            error=None
            try: timings=p.validate_timings(load(job['timing']),job['count'],duration)
            except ValueError as exc:
                error=str(exc);timings=None
                p.dump(root/'provenance'/f'FAILED-{mid}-{surah:03d}.json',{'error':error,'download':evidence,'ffprobe':probe})
            package={'reciterId':f'mp3quran_{mid}','surah':surah,'ayahCount':job['count'],
                'format':'full-surah-timed-v1','publicationStatus':'pending-upload','driveFileId':None,
                'audioFile':audio.name,'totalDurationMs':duration,'verseTimings':timings,
                'files':{audio.name:p.sha256(audio)},'bitrate':bitrate,
                'source':{'provider':'mp3quran','url':job['url'],'reciterId':job['reciter']['reciter_id'],
                    'moshafId':mid,'timingUrl':contract['timing_template'].format(surah=surah,moshaf_id=mid),
                    'timingSha256':job['timing_sha256'],'recordingStyle':'Mojawwad' if mid==133 else 'Murattal'}}
            if timings is not None:
                package['source'].update({'timingPolicy':p.TIMING_POLICY,'timingEndBeyondAudioMs':max(0,timings[-1]['endMs']-duration)})
            archive=Path(scratch)/f'{surah:03d}.zip'
            p.package_audio(audio,archive)
            package.update({'bytes':archive.stat().st_size,'sha256':p.sha256(archive)})
            record={'path':p.package_path(package),'validationError':error,'audioBytes':job['size'],
                'measuredBitrateKbps':bitrate,'download':evidence,'ffprobe':probe,
                'timingCapture':str(job['timing'].relative_to(root)),'package':package}
            verify_archive(archive,record)
            publisher.publish(archive,record['path'],package['bytes'],package['sha256'])
            # Record is committed only after verified durable archive publication.
            p.dump(record_path,record)
            return record,'downloaded'

    records=[]; errors=[]; counts={'resumed':0,'reused':0,'downloaded':0,'failed':0}
    # Bounded active tasks; per-task errors do not discard the other valid archives.
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        pending={}; iterator=iter(jobs)
        def submit_one():
            job=next(iterator,None)
            if job is not None: pending[executor.submit(process,job)]=job
        for _ in range(workers): submit_one()
        while pending:
            done,_=concurrent.futures.wait(pending,return_when=concurrent.futures.FIRST_COMPLETED)
            for future in done:
                job=pending.pop(future)
                try:
                    record,kind=future.result();records.append(record);counts[kind]+=1
                    status='BLOCKED-SOURCE' if record['validationError'] else kind.upper()
                except Exception as exc:
                    status='FAILED';counts['failed']+=1
                    errors.append({'moshafId':job['mid'],'surah':job['surah'],'error':str(exc)})
                    p.dump(root/'provenance'/f"ERROR-{job['mid']}-{job['surah']:03d}.json",errors[-1])
                print(f"[{len(records)+len(errors)}/570] {status} {job['mid']}/{job['surah']:03d} {json.dumps(counts)}",flush=True)
                submit_one()
    records.sort(key=lambda r:(r['package']['reciterId'],r['package']['surah']))
    p.dump(root/'manifest.json',{'format':'full-surah-timed-v1','contentVersion':'0.0.1','packages':records})
    failures=[{'path':r['path'],'error':r['validationError']} for r in records if r['validationError']]
    summary={'status':'blocked' if errors or failures or len(records)!=570 else ('verified-local-pending-upload' if local else 'verified-ssh-pending-upload'),
        'packages':len(records),'expectedPackages':570,'sourceMP3s':len(records),'workers':workers,
        'sourceBytes':sum(r['audioBytes'] for r in records),'zipBytes':sum(r['package']['bytes'] for r in records),
        'canonicalTimingRows':sum(len(r['package']['verseTimings'] or []) for r in records),
        **storage_summary(local, not errors and len(records)==570),
        'remote':remote if not local else None,'remoteRoot':remote_root if not local else None,'auditoryAlignmentVerified':False,
        'unmodified':True,'timingFailures':failures,'buildErrors':errors,'progress':counts,
        'sourceTimingWarnings':p.timing_warnings([r for r in records if not r['validationError']])}
    p.dump(root/'verification-summary.json',summary)
    p.dump(root/'upload-map.template.json',{'contentVersion':'0.0.1','driveFolderId':None,
        'files':[{'path':r['path'],'driveFileId':None} for r in records]})
    published_path=existing_root/'audio_catalog.published.json'
    if published_path.exists():
        published=load(published_path); valid={r['path']:r['package'] for r in records}
        known=[]
        for package in published['packages']:
            path=p.package_path(package)
            if path in valid and package['sha256']==valid[path]['sha256'] and package['bytes']==valid[path]['bytes']:
                known.append({'path':path,'driveFileId':package['driveFileId']})
        p.dump(root/'known-upload-map.json',{'contentVersion':'0.0.1','driveFolderId':published.get('driveFolderId'),'files':known})
    release_gate(root,records,contract)
    if errors: raise ValueError('build errors; see verification-summary.json')
    catalog={'version':2,'provider':'mp3quran','contentVersion':'0.0.1','driveFolderId':None,'reciters':[],'packages':[]}
    for r in contract['reciters']:
        mid=r['selected_moshaf']['id'];rid=f'mp3quran_{mid}'
        rates=[record['measuredBitrateKbps'] for record in records if record['package']['reciterId']==rid]
        catalog['reciters'].append({'id':rid,'name':p.NAMES[mid],'bitrate':max(sorted(set(rates)),key=rates.count),
            'sourceReciterId':r['reciter_id'],'moshafId':mid,'style':'Mojawwad' if mid==133 else 'Murattal',
            'measuredBitratesKbps':sorted(set(rates))})
    for record in records:
        package=copy.deepcopy(record['package'])
        package.update({'publicationStatus':'pending-upload','driveFileId':None,'bitrate':record['measuredBitrateKbps']})
        catalog['packages'].append(package)
    p.dump(root/'audio_catalog.candidate.json',catalog)
    p.checksums(root)
    print(json.dumps(summary),flush=True)
    return summary


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',required=True)
    parser.add_argument('--existing-root',required=True)
    parser.add_argument('--remote')
    parser.add_argument('--remote-root')
    parser.add_argument('--local',action='store_true',help='Keep durable archives under ROOT/packages; no SSH/SCP')
    parser.add_argument('--workers',type=int,default=2)
    args=parser.parse_args()
    if not args.local and (not args.remote or not args.remote_root):
        parser.error('--remote and --remote-root are required unless --local is used')
    if args.local:
        build(args.root,args.existing_root,args.remote,args.remote_root,args.workers,local=True)
    else:
        build(args.root,args.existing_root,args.remote,args.remote_root,args.workers)


if __name__=='__main__':
    main()
