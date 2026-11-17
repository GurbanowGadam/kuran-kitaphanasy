#!/usr/bin/env python3
"""Fail-closed anonymous Drive metadata inventory, not ZIP/hash verification.

Read a freshly captured PUBLIC frontend list URL from --list-url-file. No
cookies, login credentials, request URLs or headers are stored in provenance.
Only the final complete, size-matched inventory replaces the output map.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

FOLDER_MIME = 'application/vnd.google-apps.folder'
FIELD_MASK = 'items(id,parent,title,mime_type,file_size),continuation_token'
MAX_PAGES = 20
MAX_RESPONSE_BYTES = 8 * 1024 * 1024


class InventoryError(ValueError):
    """Inventory cannot safely be published."""


def validate_url(url):
    parsed = urllib.parse.urlsplit(url)
    query = urllib.parse.parse_qs(parsed.query)
    if (parsed.scheme != 'https' or parsed.netloc != 'drivefrontend-pa.clients6.google.com'
            or parsed.path != '/v1/items:list' or parsed.fragment
            or set(query) != {'key'} or len(query['key']) != 1 or not query['key'][0]):
        raise InventoryError('Expected a captured public Drive frontend items:list URL with key')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise InventoryError('Public Drive list redirect refused')


def public_post(url, body):
    """Read-only public listing; do not retry denial or expose URL in errors."""
    validate_url(url)
    request = urllib.request.Request(url, json.dumps(body).encode(), headers={
        'Content-Type': 'application/json+protobuf',
        'x-goog-fieldmask': FIELD_MASK,
        'Origin': 'https://drive.google.com',
        'Referer': 'https://drive.google.com/',
    }, method='POST')
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=30) as response:
            if response.status != 200:
                raise InventoryError('Public Drive listing did not return HTTP 200')
            data = response.read(MAX_RESPONSE_BYTES + 1)
            if len(data) > MAX_RESPONSE_BYTES:
                raise InventoryError('Public Drive response exceeds size limit')
            return data
    except urllib.error.HTTPError as error:
        raise InventoryError(f'Public Drive listing HTTP {error.code}; stopped without retry') from None
    except (OSError, urllib.error.URLError, ValueError) as error:
        if isinstance(error, InventoryError):
            raise
        raise InventoryError('Public Drive listing transport failed; URL suppressed') from None


def atomic_write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.' + path.name, delete=False) as stream:
            name = stream.name
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if name is not None and os.path.exists(name):
            os.unlink(name)


def identifier(value):
    return isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9_-]+', value) is not None


def positive_size(value):
    if type(value) is int and value > 0:
        return value
    if isinstance(value, str) and re.fullmatch(r'[0-9]+', value) and int(value) > 0:
        return int(value)
    raise InventoryError('Missing or invalid file size')


def load_inputs(root, folder_id):
    try:
        candidate = json.loads((root / 'audio_catalog.candidate.json').read_bytes())
        known = json.loads((root / 'known-upload-map.json').read_bytes())
        reciters = [r['id'] for r in candidate['reciters']]
        if (candidate['contentVersion'] != '0.0.1' or len(reciters) != 5
                or len(set(reciters)) != 5 or not all(identifier(r) for r in reciters)):
            raise InventoryError('Candidate must contain five unique reciters for 0.0.1')
        expected = {}
        for package in candidate['packages']:
            rid, surah = package['reciterId'], package['surah']
            if rid not in reciters or type(surah) is not int or not 1 <= surah <= 114:
                raise InventoryError('Invalid candidate reciter/surah pair')
            path = f'packages/{rid}/{surah:03}.zip'
            if path in expected:
                raise InventoryError('Duplicate candidate pair')
            expected[path] = positive_size(package['bytes'])
        if set(expected) != {f'packages/{rid}/{s:03}.zip' for rid in reciters for s in range(1, 115)}:
            raise InventoryError('Candidate must cover exactly all 570 pairs')
        if known['contentVersion'] != '0.0.1' or known['driveFolderId'] != folder_id:
            raise InventoryError('Known map version/root mismatch')
        prior = {}
        prior_ids = set()
        for row in known['files']:
            path, fid = row['path'], row['driveFileId']
            if path not in expected or path in prior or fid in prior_ids or not identifier(fid):
                raise InventoryError('Invalid or duplicate known map entry')
            prior[path] = fid
            prior_ids.add(fid)
        if len(prior) != 75:
            raise InventoryError('Original known map must contain exactly 75 IDs')
        return reciters, expected, prior
    except (KeyError, TypeError, json.JSONDecodeError) as error:
        raise InventoryError('Malformed candidate or known map') from None


def list_folder(url, parent, label, evidence, transport, seen_ids):
    token, tokens, names, rows = None, set(), set(), []
    for page in range(1, MAX_PAGES + 1):
        query = [None] * 44
        query[4], query[21], query[24], query[35], query[43] = 0, 0, [4, 1, 1], [[1]], [[parent, 0]]
        raw = transport(url, [query, [50, token, [2, 5]]])
        if not isinstance(raw, bytes):
            raise InventoryError('Listing transport must return raw bytes')
        # Exact response bytes only: no request URL, key or headers.
        atomic_write(evidence / f'{label}-page-{page:03}.json', raw)
        try:
            data = json.loads(raw)
        except (ValueError, UnicodeError):
            raise InventoryError('Public Drive response is not JSON') from None
        if not isinstance(data, list) or not 1 <= len(data) <= 2 or not isinstance(data[0], list):
            raise InventoryError('Error-shaped or malformed listing response')
        next_token = data[1] if len(data) == 2 else None
        if next_token is not None and (not isinstance(next_token, str) or not next_token):
            raise InventoryError('Malformed continuation token')
        if len(data[0]) > 50:
            raise InventoryError('Listing exceeds requested page size')
        for row in data[0]:
            if not isinstance(row, list) or len(row) < 4:
                raise InventoryError('Malformed item array')
            fid, parents, name, mime = row[:4]
            if not identifier(fid) or parents != [parent]:
                raise InventoryError('Invalid item ID or parent mismatch')
            if not isinstance(name, str) or not name or not isinstance(mime, str):
                raise InventoryError('Invalid item title or MIME')
            if fid in seen_ids or name in names:
                raise InventoryError('Duplicate item ID or name')
            seen_ids.add(fid)
            names.add(name)
            rows.append(row)
        if next_token is None:
            return rows
        if next_token in tokens:
            raise InventoryError('Repeated continuation token')
        tokens.add(next_token)
        token = next_token
    raise InventoryError('Public Drive listing page limit exceeded')


def discover(root, list_url, folder_id, output, *, transport=None):
    validate_url(list_url)
    if not identifier(folder_id):
        raise InventoryError('Invalid root folder ID')
    root = Path(root)
    reciters, expected, prior = load_inputs(root, folder_id)
    evidence = root / 'provenance' / 'drive-inventory'
    # Separate runs retain earlier raw evidence without mixing stale page counts.
    evidence.mkdir(parents=True, exist_ok=True)
    evidence = Path(tempfile.mkdtemp(prefix='run-', dir=evidence))
    transport = transport or public_post
    seen_ids = {folder_id}
    folders = list_folder(list_url, folder_id, 'root', evidence, transport, seen_ids)
    if (len(folders) != 5 or {row[2] for row in folders} != set(reciters)
            or any(row[3] != FOLDER_MIME for row in folders)):
        raise InventoryError('Root must contain exactly the five candidate reciter folders')
    found = {}
    for folder in sorted(folders, key=lambda row: row[2]):
        rid = folder[2]
        rows = list_folder(list_url, folder[0], rid, evidence, transport, seen_ids)
        for row in rows:
            fid, _, name, mime = row[:4]
            path = f'packages/{rid}/{name}'
            if path not in expected or mime != 'application/zip' or len(row) <= 13:
                raise InventoryError('Unexpected package name, MIME or missing size')
            if positive_size(row[13]) != expected[path]:
                raise InventoryError(f'Package size mismatch: {path}')
            if path in prior and prior[path] != fid:
                raise InventoryError(f'Original known Drive ID changed: {path}')
            found[path] = fid
        if len(rows) != 114:
            raise InventoryError(f'Incomplete surah coverage: {rid}')
    if set(found) != set(expected) or len(set(found.values())) != 570:
        raise InventoryError('Inventory must cover exactly 570 unique packages')
    result = {'contentVersion': '0.0.1', 'driveFolderId': folder_id,
              'files': [{'path': path, 'driveFileId': found[path]} for path in sorted(found)]}
    atomic_write(output, (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode())
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--list-url-file', type=Path, required=True)
    parser.add_argument('--folder-id', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        result = discover(args.root, args.list_url_file.read_text().strip(), args.folder_id, args.output)
    except (InventoryError, OSError, UnicodeError) as error:
        # Do not print arbitrary OS/transport exceptions containing captured URLs.
        message = str(error) if isinstance(error, InventoryError) else 'Local input/output failure'
        print(f'Inventory failed: {message}', file=sys.stderr)
        return 1
    print(f'Validated metadata inventory: {len(result["files"])} packages; {args.output}')
    print('Listing sizes matched; remote ZIP bytes/SHA-256 are NOT verified by this tool.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
