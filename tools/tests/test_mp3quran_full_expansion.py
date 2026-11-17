import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

TOOLS = Path(__file__).resolve().parents[1] / 'mp3quran'
sys.path.insert(0, str(TOOLS))

class ExpansionTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue((TOOLS / 'expand_full_quran.py').exists(), 'full expansion implementation missing')
        import expand_full_quran
        self.m = expand_full_quran

    def test_local_atomic_commit_and_reuse(self):
        from unittest.mock import patch
        import os
        with tempfile.TemporaryDirectory() as d:
            source=Path(d)/'source'; source.write_bytes(b'original')
            root=Path(d)/'release'; relative='packages/r/001.zip'
            target=root/relative; digest=hashlib.sha256(b'original').hexdigest()
            publisher=self.m.LocalPublisher(root)
            self.assertFalse(publisher.matches(relative,8,digest))
            replace=os.replace
            def commit(stage, destination):
                self.assertEqual(Path(stage).parent,target.parent)
                self.assertFalse(target.exists())
                self.assertEqual(Path(stage).read_bytes(),b'original')
                return replace(stage,destination)
            with patch.object(self.m.os,'replace',side_effect=commit), patch.object(self.m.os,'fsync',wraps=os.fsync) as sync:
                publisher.publish(source,relative,8,digest)
                self.assertGreaterEqual(sync.call_count,2)
            self.assertTrue(publisher.matches(relative,8,digest))
            self.assertFalse(publisher.matches(relative,9,digest))
            self.assertFalse(publisher.matches(relative,8,'0'*64))
            self.assertEqual(list(target.parent.iterdir()),[target])

    def test_local_rejects_invalid_source_and_corrupt_stage_preserving_target(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as d:
            source=Path(d)/'source'; source.write_bytes(b'original')
            root=Path(d)/'release'; relative='packages/r/001.zip'
            target=root/relative; target.parent.mkdir(parents=True); target.write_bytes(b'previous')
            publisher=self.m.LocalPublisher(root); digest=hashlib.sha256(b'original').hexdigest()
            for size,sha in [(9,digest),(8,'0'*64)]:
                with self.assertRaises(ValueError): publisher.publish(source,relative,size,sha)
            def corrupt(src,dst): Path(dst).write_bytes(b'corrupt!')
            with patch.object(self.m.shutil,'copyfile',side_effect=corrupt):
                with self.assertRaises(ValueError): publisher.publish(source,relative,8,digest)
            self.assertEqual(target.read_bytes(),b'previous')
            self.assertEqual(list(target.parent.iterdir()),[target])
            with self.assertRaises(ValueError): publisher.matches('../escape',8,digest)

    def test_local_cli_needs_no_remote_arguments(self):
        from unittest.mock import patch
        with patch.object(sys,'argv',['expand','--root','full','--existing-root','old','--local']), patch.object(self.m,'build') as build:
            self.m.main()
        build.assert_called_once_with('full','old',None,None,2,local=True)

    def test_remote_cli_still_requires_remote_arguments(self):
        from unittest.mock import patch
        with patch.object(sys,'argv',['expand','--root','full','--existing-root','old']), self.assertRaises(SystemExit):
            self.m.main()

    def test_storage_summary_is_not_drive_verification(self):
        for local,storage in [(True,'local'),(False,'remote')]:
            flags=self.m.storage_summary(local,True)
            self.assertEqual(flags['archiveStorage'],storage)
            self.assertTrue(flags['storageVerified'])
            self.assertEqual(flags['remoteVerified'],not local)
            self.assertFalse(flags['driveVerified'])
        self.assertFalse(self.m.storage_summary(False,False)['remoteVerified'])

    def test_remote_commit_verifies_before_atomic_rename(self):
        calls = []
        def run(argv, **kwargs):
            calls.append((argv, kwargs))
            class Result: stdout = 'MATCH\n'
            return Result()
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'a.zip'; p.write_bytes(b'archive')
            publisher = self.m.RemotePublisher('panda@host', '/safe/root', run=run)
            publisher.publish(p, 'packages/mp3quran_92/001.zip', 7, hashlib.sha256(b'archive').hexdigest())
        self.assertEqual([x[0][0] for x in calls], ['ssh', 'scp', 'ssh'])
        script = calls[-1][1]['input']
        self.assertLess(script.index('if size !='), script.index('os.replace'))
        self.assertIn('os.fsync', script)
        self.assertIn('file_digest', script)

    def test_remote_mismatch_cannot_commit(self):
        calls = []
        def run(argv, **kwargs):
            calls.append(argv)
            if argv[0] == 'ssh' and 'os.replace' in kwargs.get('input', ''):
                raise ValueError('remote hash mismatch')
            class Result: stdout = ''
            return Result()
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'x';p.write_bytes(b'x')
            with self.assertRaises(ValueError):
                self.m.RemotePublisher('p@host','/root',run=run).publish(p,'packages/x/001.zip',1,hashlib.sha256(b'x').hexdigest())
        self.assertEqual(len(calls),3)

    def test_real_remote_script_refuses_corrupt_staging(self):
        import shutil
        import subprocess
        with tempfile.TemporaryDirectory() as d:
            local=Path(d)/'source';local.write_bytes(b'original')
            target=Path(d)/'remote/packages/r/001.zip'
            def run(argv, **kwargs):
                if argv[0]=='scp':
                    stage=Path(argv[-1].split(':',1)[1])
                    stage.write_bytes(b'corrupt!')
                    return subprocess.CompletedProcess(argv,0)
                return subprocess.run([sys.executable,'-'],**kwargs)
            publisher=self.m.RemotePublisher('p@host',str(Path(d)/'remote'),run=run)
            with self.assertRaises(subprocess.CalledProcessError):
                publisher.publish(local,'packages/r/001.zip',8,hashlib.sha256(b'original').hexdigest())
            self.assertFalse(target.exists())

    def test_real_remote_script_success_and_resume(self):
        import shutil
        import subprocess
        with tempfile.TemporaryDirectory() as d:
            local=Path(d)/'source';local.write_bytes(b'original')
            def run(argv, **kwargs):
                if argv[0]=='scp':
                    shutil.copyfile(argv[-2],argv[-1].split(':',1)[1])
                    return subprocess.CompletedProcess(argv,0)
                return subprocess.run([sys.executable,'-'],**kwargs)
            publisher=self.m.RemotePublisher('p@host',str(Path(d)/'remote'),run=run)
            digest=hashlib.sha256(b'original').hexdigest()
            self.assertFalse(publisher.matches('packages/r/001.zip',8,digest))
            publisher.publish(local,'packages/r/001.zip',8,digest)
            self.assertTrue(publisher.matches('packages/r/001.zip',8,digest))
            self.assertFalse(publisher.matches('packages/r/001.zip',9,digest))

    def test_incomplete_contract_and_release_gate(self):
        with self.assertRaises(ValueError): self.m.validate_contract({'target_surahs':[1]})
        with self.assertRaises(ValueError): self.m.validate_coverage([], {'reciters':[], 'target_surahs':list(range(1,115))})

    def test_source_error_blocks_and_removes_stale_candidate(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); (root/'audio_catalog.candidate.json').write_text('{}')
            with self.assertRaises(ValueError): self.m.release_gate(root,[{'validationError':'original interval invalid'}],{})
            self.assertFalse((root/'audio_catalog.candidate.json').exists())

    def test_head_length_mismatch_blocks_before_download(self):
        class Response:
            status=200
            headers={'Content-Length':'514'}
            def __enter__(self): return self
            def __exit__(self,*args): pass
        with self.assertRaises(ValueError):
            self.m.verify_head('https://example/001.mp3',513,opener=lambda *a,**k:Response())

    def test_prefix_uses_complete_512_bytes(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'x';p.write_bytes(b'a'*512+b'b')
            evidence={'bytes_read':512,'sha256':hashlib.sha256(b'a'*512).hexdigest(),'content_range':'bytes 0-511/513'}
            self.m.verify_source(p,evidence)
            p.write_bytes(b'a'*511+b'z'+b'b')
            with self.assertRaises(ValueError): self.m.verify_source(p,evidence)

    def test_reuse_guard_rejects_changed_timing_and_source_size(self):
        p={'reciterId':'mp3quran_92','surah':1,'ayahCount':1,'audioFile':'001.mp3','format':'full-surah-timed-v1','source':{'url':'https://example/001.mp3','timingSha256':'good'}}
        record={'path':'packages/mp3quran_92/001.zip','audioBytes':513,'package':p,'download':{'bytes':513}}
        job={'mid':92,'surah':1,'count':1,'url':'https://example/001.mp3','timing_sha256':'good','size':513}
        self.m.guard_record(record,job)
        job['timing_sha256']='changed'
        with self.assertRaises(ValueError): self.m.guard_record(record,job)
        job['timing_sha256']='good';job['size']=514
        with self.assertRaises(ValueError): self.m.guard_record(record,job)

    def test_local_build_resumes_verified_archive_without_download_and_still_gates_570(self):
        from unittest.mock import patch
        import contextlib
        import io
        import shutil
        old=Path('/home/gadamgurban/kuran-mp3quran-v0.0.1')
        contract=self.m.load(old/'provenance/source-contract.json')
        reciter=contract['reciters'][0]
        job=self.m.make_job(old,contract,reciter,1)
        record=self.m.load(old/f"provenance/packages/{job['mid']}-001.json")
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/'full'
            self.m.p.dump(root/'provenance/source-contract.json',dict(contract,reciters=[reciter],target_surahs=[1]))
            self.m.p.dump(root/f"provenance/packages/{job['mid']}-001.json",record)
            archive=root/record['path']; archive.parent.mkdir(parents=True)
            shutil.copyfile(old/record['path'],archive)
            with patch.object(self.m,'validate_contract'), patch.object(self.m,'make_job',return_value=job), \
                 patch.object(self.m,'verify_head') as head, \
                 patch.object(self.m,'guard_record',wraps=self.m.guard_record) as guard, \
                 patch.object(self.m.p,'download',side_effect=AssertionError('must resume')), \
                 patch.object(self.m,'RemotePublisher',side_effect=AssertionError('no SSH')), \
                 contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(ValueError,'570'):
                    self.m.build(root,old,local=True,workers=1)
            head.assert_called_once_with(job['url'],job['size'])
            guard.assert_called_once()
            summary=self.m.load(root/'verification-summary.json')
            self.assertEqual(summary['progress']['resumed'],1)
            self.assertEqual(summary['archiveStorage'],'local')
            self.assertFalse(summary['remoteVerified'])
            self.assertEqual(summary['status'],'blocked')
            self.assertFalse((root/'audio_catalog.candidate.json').exists())

    def test_existing_provenance_compatible(self):
        root=Path('/home/gadamgurban/kuran-mp3quran-v0.0.1')
        record=json.loads((root/'provenance/packages/92-001.json').read_text())
        c=json.loads((root/'provenance/source-contract.json').read_text())
        r=c['reciters'][0]
        job=self.m.make_job(root,c,r,1)
        self.m.guard_record(record,job)
        self.m.verify_archive(root/record['path'],record)

if __name__ == '__main__': unittest.main()
