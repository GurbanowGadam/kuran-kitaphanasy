"""Bounded anonymous public Drive GET transport; no credentials or uploads."""
import hashlib
import http.client
import http.cookiejar
from html.parser import HTMLParser
from pathlib import Path
import re
import time
import urllib.error
import urllib.parse
import urllib.request

HTML_LIMIT = 256 * 1024
HOSTS = {'drive.google.com', 'drive.usercontent.google.com'}


def trusted_url(url):
    p = urllib.parse.urlsplit(url)
    if (p.scheme != 'https' or p.hostname not in HOSTS or p.username or
            p.password or p.port not in (None, 443) or p.fragment):
        raise ValueError('untrusted Drive URL')
    return url


class TrustedRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        trusted_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class ApprovalForm(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.forms = []
        self.current = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'form':
            if self.current is not None:
                raise ValueError('nested Drive form')
            if attrs.get('id') == 'download-form':
                self.current = (attrs, {})
                self.forms.append(self.current)
        elif tag == 'input' and self.current is not None and attrs.get('type') == 'hidden':
            name = attrs.get('name')
            if name not in {'id', 'export', 'confirm', 'uuid'} or name in self.current[1]:
                raise ValueError('unexpected Drive form field')
            self.current[1][name] = attrs.get('value', '')

    def handle_endtag(self, tag):
        if tag == 'form': self.current = None


def confirmation_url(body, base, fid):
    parser = ApprovalForm()
    parser.feed(body.decode('utf-8', errors='strict'))
    if len(parser.forms) != 1:
        raise ValueError('Drive permission/quota page or missing approval form')
    attrs, fields = parser.forms[0]
    action = trusted_url(urllib.parse.urljoin(base, attrs.get('action', '')))
    p = urllib.parse.urlsplit(action)
    if (attrs.get('method', 'get').lower() != 'get' or p.path not in ('/download', '/uc')
            or p.query or fields.get('id') != fid or fields.get('export') != 'download'
            or not fields.get('confirm') or any(len(v) > 1024 for v in fields.values())):
        raise ValueError('invalid Drive approval form identity/action')
    return action + '?' + urllib.parse.urlencode(fields)


def _download(opener, fid, target, expected, max_bytes):
    url = 'https://drive.google.com/uc?' + urllib.parse.urlencode({'export': 'download', 'id': fid})
    for hop in range(3):
        trusted_url(url)
        request = urllib.request.Request(url, headers={'User-Agent': 'public-drive-verifier/1.0'})
        with opener.open(request, timeout=90) as response:
            final_url = trusted_url(response.geturl())
            if response.status != 200: raise ValueError('Drive response is not HTTP 200')
            mime = response.headers.get('Content-Type', '').lower()
            if 'html' in mime:
                body = response.read(HTML_LIMIT + 1)
                if len(body) > HTML_LIMIT: raise ValueError('Drive HTML exceeds limit')
                if hop == 2: raise ValueError('Drive confirmation hop limit')
                url = confirmation_url(body, final_url, fid)
                continue
            length = response.headers.get('Content-Length')
            if length is not None and (not length.isdecimal() or int(length) != expected):
                raise ValueError('Drive Content-Length mismatch')
            prefix = response.read(4)
            if prefix != b'PK\x03\x04': raise ValueError('Drive response is not a ZIP')
            digest = hashlib.sha256()
            size = 0
            with target.open('wb') as out:
                block = prefix
                while block:
                    size += len(block)
                    if size > min(expected, max_bytes): raise ValueError('Drive byte bound exceeded')
                    digest.update(block)
                    out.write(block)
                    block = response.read(min(1024 * 1024, expected - size + 1))
            if size != expected: raise ValueError('Drive byte length mismatch')
            return {'bytes': size, 'sha256': digest.hexdigest(),
                    'urlHost': urllib.parse.urlsplit(final_url).hostname}
    raise ValueError('Drive download failed')


def download_drive(fid, target, expected, max_bytes=128 * 1024 * 1024):
    """Fully read one ZIP, bounded by declared size; return non-secret evidence."""
    if not isinstance(fid, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', fid):
        raise ValueError('invalid Drive file ID')
    if type(expected) is not int or expected < 4 or expected > max_bytes:
        raise ValueError('invalid expected Drive byte size')
    target = Path(target)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), TrustedRedirect(),
                                        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    for attempt in range(3):
        try:
            return _download(opener, fid, target, expected, max_bytes)
        except (urllib.error.URLError, OSError, http.client.HTTPException) as exc:
            target.unlink(missing_ok=True)
            transient = not isinstance(exc, urllib.error.HTTPError) or exc.code in (408, 429, 500, 502, 503, 504)
            if attempt == 2 or not transient:
                raise ValueError('public Drive transport failed') from None
            time.sleep(attempt + 1)
        except Exception:
            target.unlink(missing_ok=True)
            raise
