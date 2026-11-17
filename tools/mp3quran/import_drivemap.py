"""Fail-closed local audit / explicitly requested Drive publication.
Never uploads files. --local-only never writes or marks published.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from drive_download import download_drive
from pipeline import (MAX_AUDIO, download, dump, measure, package_path,
                      require_valid_release, sha256, validate_binding,
                      validate_map, validate_timings, verify_digest,
                      validate_timing_policy, timing_warnings)


def audit(root):
    root=Path(root).resolve()
    manifest=json.loads((root/'manifest.json').read_text())
    records=manifest['packages']
    contract=json.loads((root/'provenance/source-contract.json').read_text())
    reciters={f"mp3quran_{r['selected_moshaf']['id']}":r for r in contract['reciters']}
    expected={(rid,s) for rid in reciters for s in contract['target_surahs']}
    actual=[(r['package']['reciterId'],r['package']['surah']) for r in records]
    if len(actual)!=len(set(actual)) or set(actual)!=expected: raise ValueError('manifest missing/duplicate/extra pairs')
    errors=[]
    for record in records:
        p=record['package'];rid=p['reciterId'];s=p['surah'];r=reciters[rid];mid=r['selected_moshaf']['id']
        validate_binding(r)
        source=p['source'];url=r['selected_moshaf']['server']+f'{s:03d}.mp3'
        if source['url']!=url or source['moshafId']!=mid or source['reciterId']!=r['reciter_id'] or source['provider']!='mp3quran': raise ValueError('source identity mismatch')
        if source['timingUrl']!=contract['timing_template'].format(surah=s,moshaf_id=mid): raise ValueError('timing URL mismatch')
        path=root/package_path(p)
        if record['path']!=package_path(p) or p['format']!='full-surah-timed-v1': raise ValueError('package path/format mismatch')
        if p['bytes']>MAX_AUDIO: raise ValueError('ZIP too large')
        verify_digest(path,p['bytes'],p['sha256'])
        timing=root/'provenance/timings'/f'timing-{mid}-{s:03d}.json'
        if sha256(timing)!=source['timingSha256'] or sha256(timing)!=contract['verification'][str(mid)]['timing'][str(s)]['sha256']: raise ValueError('timing provenance mismatch')
        count=contract['expected_verse_counts'][str(s)]
        if p['ayahCount']!=count: raise ValueError('wrong canonical count')
        with tempfile.TemporaryDirectory(prefix='mp3quran-audit-') as d, zipfile.ZipFile(path) as z:
            name=f'{s:03d}.mp3'
            if z.namelist()!=[name] or p['audioFile']!=name or set(p['files'])!={name}: raise ValueError('ZIP must contain exactly source MP3')
            info=z.getinfo(name)
            if info.compress_type!=zipfile.ZIP_STORED or info.file_size>MAX_AUDIO or info.file_size!=record['audioBytes']: raise ValueError('invalid ZIP metadata')
            audio=Path(d)/name
            with z.open(name) as src,audio.open('wb') as out: shutil.copyfileobj(src,out,1024*1024)
            digest=sha256(audio)
            if digest!=p['files'][name] or digest!=record['download']['sha256']: raise ValueError('original MP3 hash mismatch')
            with audio.open('rb') as source_file:
                prefix=hashlib.sha256(source_file.read(512)).hexdigest()
            if prefix!=contract['verification'][str(mid)]['audio'][str(s)]['sha256']: raise ValueError('official sampled source prefix mismatch')
            duration,bitrate,probe=measure(audio)
            if duration!=p['totalDurationMs'] or bitrate!=record['measuredBitrateKbps']: raise ValueError('remeasured duration/bitrate mismatch')
            try:
                inline=validate_timings(json.loads(timing.read_text()),count,duration)
                if inline!=p['verseTimings']: raise ValueError('inline timings changed from original capture')
                validate_timing_policy(p)
            except ValueError as exc: errors.append({'path':record['path'],'error':str(exc)})
    if not errors:
        candidate=json.loads((root/'audio_catalog.candidate.json').read_text())
        if candidate['packages'] != [r['package'] for r in records]: raise ValueError('candidate differs from audited manifest')
        if candidate['driveFolderId'] is not None or any(p['driveFileId'] is not None or p['publicationStatus']!='pending-upload' for p in candidate['packages']): raise ValueError('candidate is not pending upload')
        summary=json.loads((root/'verification-summary.json').read_text())
        if summary.get('sourceTimingWarnings')!=timing_warnings(records): raise ValueError('summary timing warnings mismatch')
    return records,errors


def verify_remote(root, packages, ids, workers=3):
    """Verify every package, retaining only non-secret successful hash evidence.

    No resume/skip: even previously published IDs are downloaded in full.
    Each worker owns one temporary ZIP; failures do not cancel other jobs.
    """
    if not 1 <= workers <= 3: raise ValueError('workers must be 1..3')
    evidence_dir = Path(root)/'provenance/drive-verification'
    failures = []
    def verify_one(p):
        path = package_path(p)
        fid = ids[path]
        with tempfile.TemporaryDirectory(prefix='mp3quran-drive-verify-') as scratch:
            target = Path(scratch)/'remote.zip'
            result = download_drive(fid, target, p['bytes'], MAX_AUDIO)
            verify_digest(target, p['bytes'], p['sha256'])
            # Independently recomputed digest above is the publication gate.
            evidence = {'path': path, 'driveFileId': fid, 'bytes': p['bytes'],
                        'sha256': p['sha256'], 'urlHost': result['urlHost'],
                        'remoteVerified': True}
            dump(evidence_dir/(hashlib.sha256(path.encode()).hexdigest()+'.json'), evidence)
        print('REMOTE SHA256 VERIFIED '+path, flush=True)
    with ThreadPoolExecutor(max_workers=workers) as executor:
        jobs = {executor.submit(verify_one, p): package_path(p) for p in packages}
        for job in as_completed(jobs):
            try: job.result()
            except Exception as exc:
                failure = {'path': jobs[job], 'error': type(exc).__name__}
                failures.append(failure)
                print('REMOTE VERIFICATION FAILED '+json.dumps(failure), file=sys.stderr, flush=True)
    if failures:
        raise ValueError(f'{len(failures)} remote verification failures; publication refused: '+json.dumps(failures))


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',required=True)
    parser.add_argument('--map')
    parser.add_argument('--output',help='Explicit catalog output path; never defaults to production catalog')
    parser.add_argument('--local-only',action='store_true')
    parser.add_argument('--workers',type=int,choices=(1,2,3),default=3,
                        help='Maximum simultaneous complete ZIP downloads (default: 3)')
    args=parser.parse_args(argv)
    if args.local_only and args.output: parser.error('--local-only cannot write --output')
    if not args.local_only and (not args.map or not args.output): parser.error('publication requires both --map and --output')
    root=Path(args.root).resolve()
    if args.output and Path(args.output).expanduser().resolve() in {
            root/'audio_catalog.candidate.json', root/'manifest.json',
            Path(args.map).expanduser().resolve()}:
        parser.error('--output must not overwrite candidate, manifest or input map')
    records,errors=audit(root)
    print(json.dumps({'localPackagesAudited':len(records),'timingFailures':errors,'remoteVerified':False},ensure_ascii=False),flush=True)
    if errors: raise ValueError(f'{len(errors)} original timing failures; publication refused')
    require_valid_release(records)
    if args.local_only: return 0
    catalog=json.loads((root/'audio_catalog.candidate.json').read_text())
    if catalog['packages']!=[r['package'] for r in records]: raise ValueError('candidate differs from audited manifest')
    if catalog['provider']!='mp3quran' or catalog['contentVersion']!='0.0.1' or catalog['version']!=2: raise ValueError('unsupported catalog identity')
    if any(p['publicationStatus']!='pending-upload' or p['driveFileId'] is not None for p in catalog['packages']) or catalog['driveFolderId'] is not None: raise ValueError('only unpublished candidate may be imported')
    mapping=json.loads(Path(args.map).read_text())
    old_ids=set(json.loads((root/'provenance/legacy-drive-ids.json').read_text()))
    validate_map(catalog,mapping,old_ids)
    ids={item['path']:item['driveFileId'] for item in mapping['files']}
    published=copy.deepcopy(catalog)
    verify_remote(root, published['packages'], ids, args.workers)
    for p in published['packages']:
        p['driveFileId']=ids[package_path(p)]
        p['publicationStatus']='published'
        p['remoteVerified']=True
    published['driveFolderId']=mapping['driveFolderId']
    published['remoteVerified']=True
    # This is the only catalog write. It occurs after ALL remote bytes have passed.
    dump(Path(args.output).expanduser().resolve(),published)
    print('Published catalog written: '+str(Path(args.output).resolve()))
    return 0

if __name__=='__main__':
    try: sys.exit(main())
    except (ValueError,OSError,KeyError,zipfile.BadZipFile) as exc:
        print('REFUSED: '+str(exc),file=sys.stderr);sys.exit(1)
