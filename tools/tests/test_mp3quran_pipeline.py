import importlib.util
import json
import pathlib
import tempfile
import unittest
import zipfile

MODULE = pathlib.Path(__file__).parents[1] / 'mp3quran' / 'pipeline.py'

class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(MODULE.exists(), 'pipeline implementation missing')
        spec = importlib.util.spec_from_file_location('pipeline', MODULE)
        self.p = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.p)

    def test_exact_source_binding(self):
        row = {'reciter_id':102, 'selected_moshaf':{'id':133,'server':'https://cdn.mp3quran.net/audio/maher-muaiqly/r3/'}, 'timing_read':{'id':133,'folder_url':'https://cdn.mp3quran.net/audio/maher-muaiqly/r3/'}}
        self.p.validate_binding(row)
        row['timing_read']['id'] = 102
        with self.assertRaises(ValueError): self.p.validate_binding(row)

    def test_timing_preserved_not_clipped(self):
        rows=[{'ayah':1,'start_time':300,'end_time':700},{'ayah':2,'start_time':800,'end_time':1100}]
        expected=[{'ayah':1,'startMs':300,'endMs':700},{'ayah':2,'startMs':800,'endMs':1100}]
        self.assertEqual(self.p.validate_timings(rows,2,1200),expected)
        self.assertEqual(self.p.validate_timings(rows,2,1099),expected)
        self.assertEqual(self.p.validate_timings(rows,2,900),expected)
        with self.assertRaises(ValueError): self.p.validate_timings(rows,2,599)
        with self.assertRaises(ValueError): self.p.validate_timings(rows,3,1200)
        rows[1]['start_time']=650
        with self.assertRaises(ValueError): self.p.validate_timings(rows,2,1200)

    def test_eof_policy_boundaries(self):
        row={'ayah':1,'start_time':10,'end_time':1500}
        self.assertEqual(self.p.validate_timings([row],1,1000)[0]['endMs'],1500)
        with self.assertRaises(ValueError): self.p.validate_timings([dict(row,end_time=1501)],1,1000)
        with self.assertRaises(ValueError): self.p.validate_timings([dict(row,start_time=1000)],1,1000)
        rows=[dict(row,end_time=1001),{'ayah':2,'start_time':1100,'end_time':1200}]
        with self.assertRaises(ValueError): self.p.validate_timings(rows,2,1000)

    def test_policy_declaration_must_match(self):
        p={'totalDurationMs':1000,'verseTimings':[{'ayah':1,'startMs':0,'endMs':1200}], 'source':{'timingPolicy':'original-starts-eof-500ms-v1','timingEndBeyondAudioMs':200}}
        self.p.validate_timing_policy(p)
        p['source']['timingEndBeyondAudioMs']=0
        with self.assertRaises(ValueError): self.p.validate_timing_policy(p)

    def test_duplicate_and_noninteger_timings_fail(self):
        for rows in ([{'ayah':1,'start_time':0,'end_time':10}]*2,[{'ayah':1,'start_time':0.5,'end_time':10}]):
            with self.assertRaises(ValueError): self.p.validate_timings(rows,1,20)

    def test_zip_deterministic_unmodified_exact_single_member(self):
        with tempfile.TemporaryDirectory() as d:
            d=pathlib.Path(d); audio=d/'001.mp3'; audio.write_bytes(b'ID3'+bytes(range(256))*100)
            self.p.package_audio(audio,d/'a.zip')
            self.p.package_audio(audio,d/'b.zip')
            self.assertEqual((d/'a.zip').read_bytes(),(d/'b.zip').read_bytes())
            with zipfile.ZipFile(d/'a.zip') as z:
                self.assertEqual(z.namelist(),['001.mp3'])
                self.assertEqual(z.read('001.mp3'),audio.read_bytes())
                self.assertEqual(z.getinfo('001.mp3').compress_type,zipfile.ZIP_STORED)

    def test_map_complete_unique_new_ids(self):
        cat={'contentVersion':'0.0.1','packages':[{'reciterId':'mp3quran_92','surah':1}]}
        mapping={'contentVersion':'0.0.1','driveFolderId':'new_folder_id_123456789','files':[{'path':'packages/mp3quran_92/001.zip','driveFileId':'new_file_id_123456789'}]}
        self.p.validate_map(cat,mapping,{'legacy_file_id_123456789'})
        mapping['files'][0]['driveFileId']=None
        with self.assertRaises(ValueError): self.p.validate_map(cat,mapping,set())
        mapping['files'][0]['driveFileId']='legacy_file_id_123456789'
        with self.assertRaises(ValueError): self.p.validate_map(cat,mapping,{'legacy_file_id_123456789'})
        mapping['files']*=2
        with self.assertRaises(ValueError): self.p.validate_map(cat,mapping,set())

    def test_download_hash_includes_buffered_final_bytes(self):
        import http.server
        import threading
        data=b'official bytes not yet flushed'
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
            def log_message(self,*args): pass
        server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            with tempfile.TemporaryDirectory() as d:
                target=pathlib.Path(d)/'source.mp3'
                evidence=self.p.download(f'http://127.0.0.1:{server.server_port}/source',target,len(data))
                self.assertEqual(evidence['sha256'],self.p.sha256(target))
        finally: server.shutdown();server.server_close();thread.join()

    def test_import_cli_local_only_does_not_write_catalog(self):
        import subprocess
        tool=MODULE.with_name('import_drivemap.py')
        self.assertTrue(tool.exists(), 'Drive import tool missing')
        with tempfile.TemporaryDirectory() as d:
            result=subprocess.run(['python3',str(tool),'--root',d,'--local-only'],capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('manifest',result.stderr)
            self.assertEqual(list(pathlib.Path(d).iterdir()),[])

    def test_release_gate_refuses_any_invalid_pair(self):
        with self.assertRaises(ValueError): self.p.require_valid_release([{'validationError':'end beyond duration'}])
        self.p.require_valid_release([{'validationError':None}])

    def test_remote_hash_verification_cannot_publish_mismatch(self):
        with tempfile.TemporaryDirectory() as d:
            f=pathlib.Path(d)/'x';f.write_bytes(b'real bytes')
            self.p.verify_digest(f,10,self.p.sha256(f))
            with self.assertRaises(ValueError): self.p.verify_digest(f,10,'0'*64)
            with self.assertRaises(ValueError): self.p.verify_digest(f,9,self.p.sha256(f))

if __name__=='__main__': unittest.main()
