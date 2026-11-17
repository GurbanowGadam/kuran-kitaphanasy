"""Offline public Drive inventory contract; no network requests."""
import copy
import importlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1] / 'mp3quran'
sys.path.insert(0, str(TOOLS))
ROOT_ID = '1Ju0a7zKN_mySZdZavuCVND-ieSSrSpK_'
URL = 'https://drivefrontend-pa.clients6.google.com/v1/items:list?key=test-public-key'
RIDS = ['mp3quran_92', 'mp3quran_4', 'mp3quran_123', 'mp3quran_54', 'mp3quran_133']


def item(fid, parent, name, mime='application/zip', size=123):
    row = [None] * 14
    row[0:4] = [fid, [parent], name, mime]
    row[13] = str(size) if size is not None else None
    return row


class DriveMapTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue((TOOLS / 'discover_drive_map.py').exists(), 'inventory implementation missing')
        self.m = importlib.import_module('discover_drive_map')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.output = self.root / 'drive-map.full.json'
        self.pages = {ROOT_ID: [[[
            item('folder-' + rid, ROOT_ID, rid, 'application/vnd.google-apps.folder', None)
            for rid in RIDS], None]]}
        packages, known = [], []
        for rid in RIDS:
            rows = []
            for surah in range(1, 115):
                path = f'packages/{rid}/{surah:03}.zip'
                packages.append({'reciterId': rid, 'surah': surah, 'bytes': 123})
                rows.append(item(f'{rid}-{surah}', 'folder-' + rid, f'{surah:03}.zip'))
                if surah <= 15:
                    known.append({'path': path, 'driveFileId': f'{rid}-{surah}'})
            self.pages['folder-' + rid] = [[rows[:50], 'next1'], [rows[50:100], 'next2'], [rows[100:], None]]
        self.candidate = {'contentVersion': '0.0.1', 'reciters': [{'id': rid} for rid in RIDS], 'packages': packages}
        self.known = {'contentVersion': '0.0.1', 'driveFolderId': ROOT_ID, 'files': known}
        self.calls = []
        self.save_inputs()

    def save_inputs(self):
        (self.root / 'audio_catalog.candidate.json').write_text(json.dumps(self.candidate))
        (self.root / 'known-upload-map.json').write_text(json.dumps(self.known))

    def transport(self, url, body):
        self.assertEqual(url, URL)
        query, paging = body
        self.assertEqual(len(query), 44)
        self.assertEqual({i: x for i, x in enumerate(query) if x is not None},
                         {4: 0, 21: 0, 24: [4, 1, 1], 35: [[1]], 43: [[query[43][0][0], 0]]})
        self.assertEqual(paging[0], 50)
        self.assertEqual(paging[2], [2, 5])
        parent = query[43][0][0]
        index = {None: 0, 'next1': 1, 'next2': 2}.get(paging[1], 0)
        self.calls.append((parent, paging[1]))
        return json.dumps(self.pages[parent][index]).encode()

    def run_inventory(self):
        return self.m.discover(self.root, URL, ROOT_ID, self.output, transport=self.transport)

    def reject(self):
        self.output.write_text('previous valid map')
        with self.assertRaises(self.m.InventoryError):
            self.run_inventory()
        self.assertEqual(self.output.read_text(), 'previous valid map')

    def test_full_114_pagination_and_exact_570_map_raw_provenance(self):
        result = self.run_inventory()
        self.assertEqual(len(result['files']), 570)
        self.assertEqual(set(result), {'contentVersion', 'driveFolderId', 'files'})
        self.assertEqual(result, json.loads(self.output.read_text()))
        self.assertEqual(len(self.calls), 16)
        self.assertEqual(len({f['driveFileId'] for f in result['files']}), 570)
        for known in self.known['files']:
            self.assertIn(known, result['files'])
        raw = list((self.root / 'provenance/drive-inventory').rglob('*.json'))
        self.assertEqual(len(raw), 16)
        for path in raw:
            self.assertNotIn('test-public-key', path.read_text())
            self.assertIsInstance(json.loads(path.read_text()), list)

    def test_repeated_continuation_token(self):
        self.pages['folder-' + RIDS[0]][1][1] = 'next1'
        self.reject()

    def test_invalid_parent(self):
        self.pages['folder-' + RIDS[0]][0][0][0][1] = ['wrong']
        self.reject()

    def test_invalid_zip_mime(self):
        self.pages['folder-' + RIDS[0]][0][0][0][3] = 'text/html'
        self.reject()

    def test_invalid_folder_mime(self):
        self.pages[ROOT_ID][0][0][0][3] = 'application/zip'
        self.reject()

    def test_size_mismatch(self):
        self.pages['folder-' + RIDS[0]][0][0][0][13] = '124'
        self.reject()

    def test_missing_or_invalid_size(self):
        for value in (None, True, '-1', '123.0', 123.5):
            with self.subTest(value=value):
                self.pages['folder-' + RIDS[0]][0][0][0][13] = value
                self.reject()

    def test_duplicate_name(self):
        self.pages['folder-' + RIDS[0]][1][0][0][2] = '001.zip'
        self.reject()

    def test_duplicate_id_across_reciters(self):
        self.pages['folder-' + RIDS[1]][0][0][0][0] = RIDS[0] + '-1'
        self.reject()

    def test_incomplete_coverage(self):
        self.pages['folder-' + RIDS[0]][2][0].pop()
        self.reject()

    def test_exact_root_folders(self):
        self.pages[ROOT_ID][0][0][0][2] = 'unexpected'
        self.reject()

    def test_prior_id_change_is_explicit_error(self):
        self.pages['folder-' + RIDS[0]][0][0][0][0] = 'replacement-id'
        with self.assertRaisesRegex(self.m.InventoryError, 'known.*ID.*changed'):
            self.run_inventory()
        self.assertFalse(self.output.exists())

    def test_error_shaped_and_malformed_responses(self):
        for response in ({'error': {'code': 403}}, [None], [[], {'error': 'bad'}], [[{'id': 'bad'}], None]):
            with self.subTest(response=response):
                self.pages[ROOT_ID][0] = response
                self.reject()

    def test_maximum_pages(self):
        counter = 0
        def endless(url, body):
            nonlocal counter
            counter += 1
            return json.dumps([[], f'token-{counter}']).encode()
        with self.assertRaisesRegex(self.m.InventoryError, 'page limit'):
            self.m.discover(self.root, URL, ROOT_ID, self.output, transport=endless)
        self.assertEqual(counter, 20)

    def test_candidate_requires_exact_unique_pairs(self):
        self.candidate['packages'][-1] = copy.deepcopy(self.candidate['packages'][0])
        self.save_inputs()
        self.reject()
        self.assertEqual(self.calls, [])

    def test_known_map_requires_original_75(self):
        self.known['files'].pop()
        self.save_inputs()
        self.reject()
        self.assertEqual(self.calls, [])

    def test_reject_untrusted_endpoint_before_transport(self):
        for url in ('http://drivefrontend-pa.clients6.google.com/v1/items:list?key=x',
                    'https://evil.example/v1/items:list?key=x',
                    'https://drivefrontend-pa.clients6.google.com/v1/items:list'):
            with self.subTest(url=url), self.assertRaises(self.m.InventoryError):
                self.m.discover(self.root, url, ROOT_ID, self.output, transport=self.transport)
        self.assertEqual(self.calls, [])

    def test_http_transport_minimal_headers_and_no_leaked_exception(self):
        from unittest.mock import MagicMock
        response = MagicMock()
        response.__enter__.return_value = response
        response.status = 200
        response.read.return_value = b'[[], null]'
        with patch.object(self.m.urllib.request.OpenerDirector, 'open', return_value=response) as opened:
            self.assertEqual(self.m.public_post(URL, [[], []]), b'[[], null]')
        request = opened.call_args.args[0]
        self.assertEqual(request.get_method(), 'POST')
        self.assertEqual(json.loads(request.data), [[], []])
        self.assertEqual(dict((k.lower(), v) for k, v in request.header_items()), {
            'content-type': 'application/json+protobuf',
            'x-goog-fieldmask': 'items(id,parent,title,mime_type,file_size),continuation_token',
            'origin': 'https://drive.google.com', 'referer': 'https://drive.google.com/',
        })
        with patch.object(self.m.urllib.request.OpenerDirector, 'open', side_effect=OSError(URL)):
            with self.assertRaises(self.m.InventoryError) as error:
                self.m.public_post(URL, [[], []])
        self.assertNotIn('test-public-key', str(error.exception))


if __name__ == '__main__':
    unittest.main()
