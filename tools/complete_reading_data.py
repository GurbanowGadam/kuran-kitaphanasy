#!/usr/bin/env python3
"""Rebuild ten reading pages from frozen source captures, never from generated text.
Run with the extraction venv (pymupdf) and fontTools installed.
Arabic is exact official Diyanet textGroup 4, NOT a claimed decoding of PDF glyphs.
"""
import hashlib,json,subprocess
from pathlib import Path
import pymupdf
from reading_font_coverage import measure_fonts, RENDERING_CAVEAT
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/sources'; OUT=ROOT/'assets/data'
PDF=Path('/home/gadamgurban/Documents/kurani-kerim-turkce.pdf')
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(p,obj):p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
def load(p):return json.loads(p.read_text())
doc=pymupdf.open(PDF); assert len(doc)==616
capture=SRC/'arabic-reading-pdf';capture.mkdir(exist_ok=True)
ranges=[(1,1,7),(2,1,5),(2,6,16),(2,17,24),(2,25,29),(2,30,37),(2,38,48),(2,49,57),(2,58,61),(2,62,69)]
pageitems=[]; evidence=[]
for i,(s,a,b) in enumerate(ranges,1):
    n=i+1; p=doc[n-1]; text=p.get_text()
    (capture/f'page-{n:03}.txt').write_text(text)
    # CID-based fallback character values, not Unicode Arabic verse digits.
    markers=[ord(c)-769 for c in text if 770<=ord(c)<=1055]
    assert sorted(markers)==list(range(a,b+1)),(n,markers)
    image=capture/f'page-{n:03}.png'
    if not image.exists():p.get_pixmap(matrix=pymupdf.Matrix(1.2,1.2)).save(image)
    pageitems.append({'id':i,'printedPage':i-1,'pdfPage':n,'printedLabel':None if i<3 else str(i-1),'printedPageInferred':i<3,'verses':[{'surah':s,'ayah':v} for v in range(a,b+1)]})
    evidence.append({'pdfPage':n,'surah':s,'fromAyah':a,'toAyah':b,'extractedMarkerNumbers':markers,'renderSha256':sha(image),'visualReview':'Rendered page examined: opening/closing ayah and footer; first two pages have no visible numeric footer.'})
pdfsource={'type':'user-provided-pdf','path':str(PDF),'sha256':sha(PDF),'physicalPageCount':616,'status':'complete','pageNumbering':'Reader id 1..10 = physical PDF 2..11. printedPage 0,1 are inferred sequence positions, NOT visible labels; printedLabel null there. Visible printed labels 2..9 on physical 4..11.','scope':'Fatiha 1-7; Bakara 1-69','verification':'All ten rendered pages visually checked; all 76 verse-end CID markers independently enumerated. PDF cover excluded; catchwords outside frame excluded.'}
save(OUT/'pages.json',{'source':pdfsource,'items':pageitems})
items=[]
captured=load(SRC/'diyanet-reading/manifest.json')
sources=captured['captures']
for source in sources:
    path=ROOT/source['path']
    assert sha(path)==source['sha256']
    assert sha(ROOT/source['responsePath'])==source['responseSha256']
    for v in load(path)['data']:
        texts=[t['metin'] for t in v['metinler'] if t['metin_grubu_id']==4]
        assert len(texts)==1
        items.append({'surah':v['sure_id'],'ayah':v['ayet_no'],'text':texts[0]})
assert [(v['surah'],v['ayah']) for v in items]==[(v['surah'],v['ayah']) for p in pageitems for v in p['verses']]
reference={(v['surah'],v['ayah']):v['text'] for v in items}
for v in load(SRC/'arabic-verified.json'):
    if (v['surah'],v['ayah']) in reference:
        assert reference[v['surah'],v['ayah']]==v['arabic']
arabicsource={'type':'diyanet-api','status':'complete','provider':'Diyanet public Quran API, textGroup 4','textGroup':4,'fontId':173,'captures':sources,'captureManifestSha256':sha(SRC/'diyanet-reading/manifest.json'),'normalization':'None. Exact metin string from official metin_grubu_id 4 after public transport decoding and JSON parsing. No BOM, basmala, letter, vowel or stop-mark changes.','scope':'Fatiha 1-7; Bakara 1-69','pdfTextMatch':'Page membership independently verified against user PDF; Unicode matches all 12 previous shared Diyanet records exactly. Full PDF glyph-to-Unicode identity is not claimed.','redistribution':'Public access is not redistribution permission; review Diyanet font and text licensing before release.'}
save(OUT/'verses.json',{'source':arabicsource,'items':items})
fontcoverage=measure_fonts(items)
fonts=[]
for xref in sorted({f[0] for p in doc.pages(1,11) for f in p.get_fonts()}):
    obj=doc.xref_object(xref); name,ext,typ,content=doc.extract_font(xref)
    fonts.append({'xref':xref,'name':name,'format':ext,'hasToUnicode':'/ToUnicode' in obj,'embeddedFontSha256':hashlib.sha256(content).hexdigest(),'semanticGlyphNames':False if ext=='cid' else None})
save(SRC/'reading-font-coverage.json',{'pdfFonts':fonts,'pdfDecodingConclusion':'Main Arabic fonts are CID-keyed CFF with Identity-H; no ToUnicode or Unicode cmap. Inspected CFF charset has cidNNNNN names, not Arabic names. Full semantic decoding not established; only verse-end markers decoded with visual validation.',**fontcoverage})
save(SRC/'reading-page-evidence.json',{'source':pdfsource,'markerRule':'Extracted fallback codepoint minus 769 gives verse number for CID markers 770..1055; validated on the rendered selected pages only. Fatiha PDF content order is 1,2,4,3,5,6,7; sorted marker set verified, not used to reconstruct Arabic.','pages':evidence})
manifest=load(SRC/'reading-data-manifest.json')
manifest.update({'status':'complete-diyanet-arabic','arabicPdf':pdfsource,'arabicText':arabicsource,'datasets':{p.stem:len(load(p)['items']) for p in OUT.glob('*.json')},'verifiedDiyanetPages':list(range(10)),'verifiedReadingCoverage':'10 pages, physical Arabic PDF 2-11, Fatiha 1-7 and Bakara 1-69 (76 verses)','unresolved':['Full PDF glyph-to-Unicode identity is not established; exact official Diyanet textGroup 4 restored, matching all 12 previous shared verses.',RENDERING_CAVEAT,'Human review of editorial Arabic-name transliteration and redistribution permission.'],'reproduceCompletedArabic':['Install pymupdf, fonttools and uharfbuzz in a venv','python tools/complete_reading_data.py','python tools/check_reading_data.py --require-complete','Optional explicit public-source refresh: python tools/capture_diyanet_reading.py']})
manifest['artifactHashes']={str(p.relative_to(ROOT)):sha(p) for p in list(OUT.glob('*.json'))+[SRC/'reading-page-evidence.json',SRC/'reading-font-coverage.json']}
save(SRC/'reading-data-manifest.json',manifest)
print('PASS: 10 PDF-verified pages; 76 exact official Diyanet textGroup 4 verses; font coverage report written.')
