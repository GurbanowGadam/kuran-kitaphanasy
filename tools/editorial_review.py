"""Local owner editorial evidence; never represents independent source verification."""
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
APPROVAL_PATH = ROOT / 'assets/sources/editorial-approvals.json'

def mapping_approved(surah, ayahs, text=None):
    document = json.loads((ROOT / 'assets/data/translations.json').read_text())
    if text is None:
        matches = [b for b in document['items'] if b['surah'] == surah and b['fromAyah'] == ayahs[0] and b['toAyah'] == ayahs[-1]]
        if len(matches) != 1:
            return False
        text = matches[0]['text']
    if not APPROVAL_PATH.is_file():
        return False
    digest = hashlib.sha256(text.encode('utf-8')).hexdigest()
    approvals = json.loads(APPROVAL_PATH.read_text())
    return any(a.get('surah') == surah and a.get('mappedAyahs') == ayahs
               and a.get('status') == 'approved' and a.get('reviewer') == 'product-owner'
               and a.get('paragraphSha256') == digest
               and a.get('sourcePdfSha256') == document['source']['sha256']
               for a in approvals['items'])

def pending_mapping_reviews():
    if mapping_approved(79, [40, 41]):
        return []
    return [{'surah':79, 'physicalPdfPage':585, 'sourceLabel':'40.', 'mappedAyahs':[40,41],
             'reason':'41 label unprinted; mapping unchanged source paragraph to 40–41 awaits owner/editor approval.'}]
