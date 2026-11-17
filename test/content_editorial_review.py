"""Editorial approval is owner evidence bound to the unchanged source paragraph."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))

class EditorialApprovalTest(unittest.TestCase):
    def test_owner_confirmation_is_recorded_and_matches_source(self):
        from editorial_review import mapping_approved
        doc=json.loads((ROOT/'assets/data/translations.json').read_text())
        block=next(b for b in doc['items'] if b['id']=='79:40-41')
        self.assertTrue(mapping_approved(79, [40,41], block['text']))
        self.assertFalse(mapping_approved(79, [40,41], block['text']+' changed'))
        self.assertFalse(mapping_approved(79, [40], block['text']))
        approval=json.loads((ROOT/'assets/sources/editorial-approvals.json').read_text())['items'][0]
        self.assertEqual(approval['reviewer'],'product-owner')
        self.assertEqual(approval['verificationBasis'],'Owner reports comparison with other sources; source URLs were not supplied.')
        self.assertEqual(approval['paragraphSha256'], hashlib.sha256(block['text'].encode()).hexdigest())
    def test_parser_and_conservation_keep_anomaly_but_clear_pending_gate(self):
        from build_full_content import translations
        from check_full_content import verify_translation_conservation
        anomalies=translations()[3]
        row=next(a for a in anomalies if a['kind']=='unprinted-41-label')
        self.assertFalse(row['userReviewRequired'])
        self.assertEqual(row['reviewStatus'],'approved-by-product-owner')
        self.assertFalse(verify_translation_conservation()['humanReviewRequired'])
if __name__=='__main__': unittest.main()
