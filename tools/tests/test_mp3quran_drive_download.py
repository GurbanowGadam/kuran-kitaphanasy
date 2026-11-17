"""Offline transport and fail-closed publication regression tests."""
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import URLError
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'mp3quran'))
import importlib

FID = 'public-file_123'
HOST = 'https://drive.usercontent.google.com/download'
FORM = ('<form id="download-form" method="get" action="'+HOST+'">'
        '<input type="hidden" name="id" value="'+FID+'">'
        '<input type="hidden" name="export" value="download">'
        '<input type="hidden" name="confirm" value="t">'
        '<input type="hidden" name="uuid" value="public-token"></form>').encode()

class Response(io.BytesIO):
    def __init__(self, body, mime='application/zip', length=None, url=HOST):
        super().__init__(body)
        self.headers = {'Content-Type': mime}
        if length is not None: self.headers['Content-Length'] = str(length)
        self.status = 200
        self.url = url
    def geturl(self): return self.url

class DriveDownloadTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue((Path(__file__).resolve().parents[1]/'mp3quran/drive_download.py').exists(), 'Drive confirmation downloader missing')
        self.m = importlib.import_module('drive_download')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.target = Path(self.tmp.name)/'remote.zip'
    def run_download(self, responses, expected=8, maximum=1024):
        with patch.object(self.m.urllib.request.OpenerDirector, 'open', side_effect=responses) as opened:
            result = self.m.download_drive(FID, self.target, expected, maximum)
        return result, opened
    def test_confirmation_and_cookie_handler(self):
        with patch.object(self.m.urllib.request, 'HTTPCookieProcessor', wraps=self.m.urllib.request.HTTPCookieProcessor) as cookies:
            result, opened = self.run_download([Response(FORM,'text/html'),Response(b'PK\x03\x04data')])
        self.assertEqual(self.target.read_bytes(), b'PK\x03\x04data')
        self.assertEqual(result['urlHost'], 'drive.usercontent.google.com')
        self.assertIn('confirm=t', opened.call_args.args[0].full_url)
        cookies.assert_called_once()
    def test_large_zip_stream(self):
        import zipfile
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_STORED) as z:
            z.writestr('002.mp3', b'x'*(2*1024*1024))
        body=stream.getvalue()
        self.run_download([Response(body)],len(body),len(body))
        self.assertEqual(self.target.stat().st_size,len(body))
    def test_forms_fail_closed(self):
        for body in (b'quota exceeded', FORM.replace(FID.encode(),b'wrong'), FORM.replace(HOST.encode(),b'https://evil.example/download'), FORM.replace(b'method="get"',b'method="post"'), FORM.replace(b'name="uuid"',b'name="unexpected"')):
            with self.subTest(body=body), self.assertRaises(ValueError):
                self.run_download([Response(body,'text/html')])
            self.assertFalse(self.target.exists())
    def test_html_limit_and_confirmation_hops(self):
        for responses in ([Response(b'x'*262145,'text/html')], [Response(FORM,'text/html') for _ in range(3)]):
            with self.assertRaises(ValueError): self.run_download(responses)
    def test_size_content_length_and_prefix(self):
        for response in (Response(b'PK\x03\x04data',length=9),Response(b'PK\x03\x04toolong'),Response(b'PK'),Response(b'notazip!')):
            with self.subTest(response=response), self.assertRaises(ValueError): self.run_download([response])
            self.assertFalse(self.target.exists())
    def test_expected_exceeds_limit_before_network(self):
        with patch.object(self.m.urllib.request.OpenerDirector,'open') as opened, self.assertRaises(ValueError):
            self.m.download_drive(FID,self.target,100,99)
        opened.assert_not_called()
    def test_retry_transient(self):
        with patch.object(self.m.time,'sleep'):
            _, opened=self.run_download([URLError('temporary'),URLError('temporary'),Response(b'PK\x03\x04data')])
        self.assertEqual(opened.call_count,3)
    def test_unsafe_urls_and_redirects(self):
        for url in ('http://drive.google.com/uc','https://drive.google.com.evil/a','https://user@drive.google.com/uc','https://drive.google.com:444/uc','https://127.0.0.1/a'):
            with self.subTest(url=url), self.assertRaises(ValueError): self.m.trusted_url(url)
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.m.TrustedRedirect().redirect_request(None,None,302,'',{},url)

class PublicationTests(unittest.TestCase):
    def test_candidate_cannot_be_output(self):
        import import_drivemap as m
        with tempfile.TemporaryDirectory() as tmp, patch.object(m,'audit') as audited:
            with self.assertRaises(SystemExit):
                m.main(['--root',tmp,'--map','map.json','--output',str(Path(tmp)/'audio_catalog.candidate.json')])
            audited.assert_not_called()

    def test_parallel_all_jobs_evidence_and_failure_gate(self):
        import import_drivemap as m
        import threading
        import time
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            packages=[{'reciterId':'r','surah':i,'bytes':8,'sha256':'hash'} for i in range(1,7)]
            ids={m.package_path(p):str(p['surah']) for p in packages}
            active=0; peak=0; seen=[]; lock=threading.Lock()
            def download(fid,target,expected,max_bytes):
                nonlocal active,peak
                with lock: active+=1; peak=max(peak,active); seen.append(fid)
                time.sleep(.01)
                with lock: active-=1
                target.write_bytes(b'PK\x03\x04data')
                if fid=='2': raise ValueError('quota')
                return {'bytes':8,'sha256':'hash','urlHost':'drive.usercontent.google.com'}
            with patch.object(m,'download_drive',side_effect=download), patch.object(m,'verify_digest'):
                with self.assertRaises(ValueError): m.verify_remote(root,packages,ids,3)
            self.assertEqual(len(seen),6)
            self.assertGreater(peak,1); self.assertLessEqual(peak,3)
            self.assertEqual(len(list((root/'provenance/drive-verification').glob('*.json'))),5)
            self.assertTrue(all('driveFileId' not in p for p in packages))

if __name__=='__main__': unittest.main()
