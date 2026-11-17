#!/usr/bin/env python3
"""Extract source text in visual column order. Requires PyMuPDF.
No OCR, translation, or spelling changes. PDF page numbers are 1-based.
"""
from pathlib import Path
import json
import pymupdf
ROOT = Path(__file__).resolve().parents[1]
PDF = Path('/home/gadamgurban/Documents/kurany_kerim_turkmen_dilinde.pdf')
OUT = ROOT / 'assets/sources/pdf-extraction'
OUT.mkdir(parents=True, exist_ok=True)
doc = pymupdf.open(PDF)
all_pages=[]
for n, page in enumerate(doc, 1):
    # Mirrored margins: even PDF pages have a 255pt gutter, odd 287pt.
    # Assign whole text blocks, never clip letters at the gutter or page footer.
    split=255 if n % 2 == 0 else 287
    blocks={i:b for i,b in enumerate(page.get_text('blocks')) if b[6]==0}
    cols=[]
    for left in (True,False):
        words=[w for w in page.get_text('words') if w[5] in blocks
               and (blocks[w[5]][0] < split)==left
               and not (blocks[w[5]][4].strip().isdigit() and blocks[w[5]][1]>740)]
        lines={}
        for w in words:
            key=(w[5],w[6])
            lines.setdefault(key,[]).append(w)
        ordered=sorted(lines.values(),key=lambda ws:(round(min(w[1] for w in ws),1),min(w[0] for w in ws)))
        cols.append('\n'.join(' '.join(w[4] for w in sorted(ws,key=lambda w:w[0])) for ws in ordered))
    all_pages.append({'pdfPage':n,'left':cols[0],'right':cols[1]})
    if 2 <= n <= 16:
        for side,text in zip(('left','right'),cols):
            (OUT / f'page-{n:03d}-{side}.txt').write_text(text+'\n')
(OUT/'all-pages.json').write_text(json.dumps(all_pages,ensure_ascii=False,indent=2)+'\n')
print(f'Extracted {len(all_pages)} pages; first reading columns saved individually.')
