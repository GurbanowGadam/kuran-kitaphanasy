#!/usr/bin/env python3
"""Derive all 114 titles and opening records from frozen public /sure capture.

Use tools/build_full_content.py for a complete rebuild including validation
reports and refreshed manifest hashes. This targeted command also refreshes
Arabic titles/provenance, but does not regenerate fonts or the full manifest.
"""
from build_full_content import build_titles_metadata

if __name__ == '__main__':
    build_titles_metadata()
