#!/usr/bin/env python3
"""Compatibility entry point; production validation is check_full_content.py.

The former 76-ayah/ten-page checker and reading-data-manifest.json describe
only the original demo, NOT the current complete dataset. The original demo
project is preserved separately; this production checkout never rewrites it.
--require-complete is accepted for backward compatibility (full is mandatory).
"""
import sys
from check_full_content import verify, verify_pdf_extraction

if __name__ == '__main__':
    print('Production entry point: tools/check_full_content.py; legacy ten-page manifest is not authoritative.', flush=True)
    unknown=set(sys.argv[1:])-{'--require-complete','--pdf-extraction'}
    if unknown:raise SystemExit('Unknown flags: '+', '.join(sorted(unknown)))
    if '--pdf-extraction' in sys.argv:verify_pdf_extraction()
    else:verify()
