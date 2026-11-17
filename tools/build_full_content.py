#!/usr/bin/env python3
"""Deterministic full-source content builder. Never substitutes Arabic editions."""
import json,re,hashlib
from editorial_review import mapping_approved, pending_mapping_reviews
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/sources'; OUT=ROOT/'assets/data'
def load(path): return json.loads(path.read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path,obj): path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
def parse_numbers(s):
    values=[int(x) for x in re.findall(r'\d+',s)]
    return list(range(values[0],values[-1]+1))
def capture():
    from concurrent.futures import ThreadPoolExecutor
    from capture_diyanet_reading import fetch,decode,BASE
    folder=SRC/'diyanet-reading'
    js=(folder/'public-client.js').read_bytes()
    key=re.search(rb'const \w+="([0-9a-f]{64})";let \w+=null;function',js)[1].decode()
    def one(n):
        path=folder/f'page-{n:02}-decoded.json'; rawpath=folder/f'page-{n:02}-response.json'
        if not path.exists():
            raw=fetch(f'{BASE}/api/v2/sayfa/{n}?font_id=173'); decoded=decode(raw,key)
            o=json.loads(decoded)
            assert o['data'] and all(v['sayfa']==n for v in o['data'])
            rawpath.write_bytes(raw);path.write_bytes(decoded)
        o=load(path)
        assert o['meta']['count']==len(o['data'])
        return {'url':f'{BASE}/api/v2/sayfa/{n}?font_id=173','path':str(path.relative_to(ROOT)),'sha256':sha(path),'responsePath':str(rawpath.relative_to(ROOT)),'responseSha256':sha(rawpath),'page':n,'count':len(o['data'])}
    with ThreadPoolExecutor(max_workers=4) as pool:
        captures=[]
        # Bounded batches: an HTTP denial stops new requests, not just collection of results.
        for start in range(0,605,4):
            for c in pool.map(one,range(start,min(start+4,605))):
                captures.append(c)
                if c['page']%25==0: print('captured',c['page'],flush=True)
    old=load(folder/'manifest.json')
    import datetime
    old.setdefault('originalTenPageRetrievedAt',old['retrievedAt'])
    old['fullCaptureManifestRecordedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
    old.update({'captures':captures,'scope':'Full official 0..604 page sequence','sourceVerseCount':sum(c['count'] for c in captures),'permission':'User explicitly asserted complete source permissions for this production on 2026-11-13; assertion recorded, not an independently verified license.'})
    save(folder/'manifest.json',old)
def clean(s):
    s=s.replace('soraýa-\nrys','soraýarys')
    s=re.sub(r'-\s*\n\s*','-',s)
    return ' '.join(s.split())
def translations():
    pages=load(SRC/'pdf-extraction/all-pages.json')
    text='';spans=[]
    for p in pages:
        for side in ('left','right'):
            start=len(text);text+=p[side]+'\n';spans.append((start,len(text),p['pdfPage'],side))
    def location(pos):
        a,b,page,side=next(s for s in spans if s[0]<=pos<s[1])
        return {'pdfPage':page,'column':side,'extractionOffset':pos}
    headings=list(re.finditer(r'(?m)^(\d+)-(?:nji|njy) süre:.*$|^52-nji: «Tur» süresi$',text))
    assert len(headings)==114
    metadata=load(SRC/'diyanet-reading/surahs-decoded.json')['data']
    items=[];notes=[];descs=[];anomalies=[]
    for i,h in enumerate(headings):
        surah=i+1; count=metadata[i]['ayet_sayisi']
        end=headings[i+1].start() if i+1<len(headings) else len(text)
        body=text[h.end():end]
        pattern=r'(?m)^(\d+(?:,\s*\d+)*)(?:\.\s*|(?= Bes,))'
        matches=list(re.finditer(pattern,body))
        # Source final commentary quotes Alak 19 on its own line. It is NOT a second Agraf ayah.
        if surah==7:
            assert matches[-1][1]=='19' and matches[-2][1]=='206'
            anomalies.append({'surah':7,'kind':'commentary-numeric-citation','text':'19.','action':'kept inside final source note, not emitted as an ayah'})
            matches=matches[:-1]
        intro=body[:matches[0].start()].strip()
        if intro.startswith('('):intro=intro.split('\n',1)[1]
        if surah not in (1,9):
            idx=intro.rfind('Rahman (Mähriban)')
            if idx>=0:intro=intro[:idx]
        descs.append({'surah':surah,'text':clean(intro),**location(h.start())})
        covered=[]
        for k,m in enumerate(matches):
            nums=parse_numbers(m[1]);a,b=nums[0],nums[-1]
            nextpos=matches[k+1].start() if k+1<len(matches) else len(body)
            content=body[m.end():nextpos]
            if surah==79 and a==40:
                assert matches[k+1][1]=='42'
                b=41;nums=[40,41]
                anomalies.append({'surah':79,'sourceLabel':'40.','mappedAyahs':[40,41],'kind':'unprinted-41-label','userReviewRequired':not mapping_approved(79,[40,41],clean(content.split('Düşündiriş:')[0])),'reviewStatus':'approved-by-product-owner' if mapping_approved(79,[40,41],clean(content.split('Düşündiriş:')[0])) else 'pending-human-confirmation','action':'single unchanged source paragraph covers 40–41; no wording invented','evidence':'PDF physical 585: paragraph ends ýeri jennetdir.; next printed label is 42.'})
            if nums!=[int(x) for x in re.findall(r'\d+',m[1])]:
                anomalies.append({'surah':surah,'sourceLabel':m[1],'mappedAyahs':nums,'kind':'source-range-or-omitted-intermediate-labels'})
            covered+=nums
            parts=content.split('Düşündiriş:');tid=f'{surah}:{a}-{b}'
            item={'id':tid,'surah':surah,'fromAyah':a,'toAyah':b,'text':clean(parts[0]),'footnoteIds':[],**location(h.end()+m.start()),'sourceLabel':m[1],'sourceMarker':m[0].rstrip()}
            offset=h.end()+m.end()+len(parts[0])
            for j,n in enumerate(parts[1:],1):
                fid=f'{tid}:note-{j}';notes.append({'id':fid,'surah':surah,'fromAyah':a,'toAyah':b,'text':'Düşündiriş: '+clean(n),**location(offset)})
                item['footnoteIds'].append(fid);offset+=len('Düşündiriş:')+len(n)
            assert item['text'],tid
            items.append(item)
        assert covered==list(range(1,count+1)),(surah,covered)
    return items,notes,descs,anomalies

def build_translations():
    items,notes,descs,anomalies=translations()
    old=load(OUT/'translations.json')['items']
    for a,b in zip(old,items):
        assert all(a[k]==b[k] for k in ('id','surah','fromAyah','toAyah','text','footnoteIds','pdfPage')),(a,b)
    source=load(OUT/'translations.json')['source']
    source.update({'status':'complete','scope':'114 surahs; 6236 ayahs, source grouped paragraphs preserved','normalization':'Whitespace folded; line-end hyphens preserved without intervening whitespace; only pre-existing Fatiha soraýa- / rys joined. No Unicode normalization or wording correction. Printed missing punctuation retained as sourceLabel.','extractionSha256':sha(SRC/'pdf-extraction/all-pages.json'),'redistribution':'User explicitly asserted complete source permissions on 2026-11-13. This records user assertion; no independently verified license is claimed.'})
    for name,data in [('translations',items),('footnotes',notes),('surah_descriptions',descs)]:save(OUT/f'{name}.json',{'source':source,'items':data})
    save(SRC/'full-translation-anomalies.json',{'items':anomalies})
    print('translation',len(items),'notes',len(notes),'descriptions',len(descs),flush=True)

def build_arabic():
    manifest=load(SRC/'diyanet-reading/manifest.json')
    assert len(manifest['captures'])==605,'Full capture must finish first'
    verses=[];pages=[]
    for n,c in enumerate(manifest['captures']):
        assert sha(ROOT/c['path'])==c['sha256']
        assert sha(ROOT/c['responsePath'])==c['responseSha256']
        records=load(ROOT/c['path'])['data'];members=[]
        for v in records:
            assert v['sayfa']==n
            t=[t['metin'] for t in v['metinler'] if t['metin_grubu_id']==4]
            assert len(t)==1
            member={'surah':v['sure_id'],'ayah':v['ayet_no']}
            verses.append({**member,'text':t[0]});members.append(member)
        pages.append({'id':n+1,'printedPage':n,'pdfPage':n+2,'printedLabel':str(n) if n>=2 else None,'printedPageInferred':n<2,'verses':members})
    metadata=load(SRC/'diyanet-reading/surahs-decoded.json')['data']
    expected=[(s['id'],a) for s in metadata for a in range(1,s['ayet_sayisi']+1)]
    assert [(v['surah'],v['ayah']) for v in verses]==expected
    previous=load(OUT/'verses.json')['items']
    assert verses[:len(previous)]==previous,'Arabic changed'
    arabicsource=load(OUT/'verses.json')['source']
    arabicsource.update({'status':'complete','scope':'All 114 surahs, 6236 ayahs; official source pages 0..604','captures':manifest['captures'],'captureManifestSha256':sha(SRC/'diyanet-reading/manifest.json'),'redistribution':manifest['permission'],'pdfTextMatch':'Exact official textGroup 4 only. User PDF page marker comparison is separate evidence, not a claim that PDF CID glyphs were semantically decoded.'})
    page_source=load(OUT/'pages.json')['source']
    page_source.update({'status':'complete','scope':'Official source pages 0..604, first two pages intentionally separate','pageNumbering':'id = official sayfa + 1; physical Arabic PDF page = official sayfa + 2. First two printed labels absent; numbers inferred as before.','verification':'All official frozen page memberships; full PDF marker comparison saved separately. No claim of full visual page inspection.'})
    save(OUT/'verses.json',{'source':arabicsource,'items':verses})
    save(OUT/'pages.json',{'source':page_source,'items':pages})
    print('Arabic',len(verses),'pages',len(pages),flush=True)

def build_titles_metadata():
    """Always derive all 114 headings/opening records from the frozen /sure response."""
    from capture_diyanet_reading import decode
    folder=SRC/'diyanet-reading'
    provenance=load(OUT/'surah_titles_diyanet.json')['source']
    decoded=ROOT/provenance['decodedPath'];response=ROOT/provenance['responsePath']
    assert sha(decoded)==provenance['decodedSha256']
    assert sha(response)==provenance['responseSha256']
    js=(folder/'public-client.js').read_bytes()
    assert hashlib.sha256(js).hexdigest()==load(folder/'manifest.json')['publicClientSha256']
    key=re.search(rb'const \w+="([0-9a-f]{64})";let \w+=null;function',js)[1].decode()
    assert decode(response.read_bytes(),key)==decoded.read_bytes()
    rows=load(decoded)['data']
    assert [r['id'] for r in rows]==list(range(1,115))
    titles=[{'surah':r['id'],'name':r['ad_ar']} for r in rows]
    previous=load(OUT/'surah_titles_diyanet.json')['items']
    assert titles[:len(previous)]==previous,'Previously reviewed Arabic titles changed'
    provenance={k:v for k,v in provenance.items() if k not in ('field','scope')}
    save(OUT/'surah_titles_diyanet.json',{'source':{**provenance,'field':'data[].ad_ar; all 114 surahs copied without normalization'},'items':titles})
    places={'mekki':'Mekge','medeni':'Medine'}
    save(OUT/'surah_metadata.json',{'source':{**provenance,'field':'data[].id, ayet_sayisi, inis_yeri; all 114 surahs','placeLabels':places},'items':[{'surah':r['id'],'verseCount':r['ayet_sayisi'],'place':places[r['inis_yeri']]} for r in rows]})
    print('Arabic titles and opening metadata',len(rows),'PASS',flush=True)

def validate_fonts():
    from fontTools.ttLib import TTFont
    import uharfbuzz as hb
    from reading_font_coverage import PRIMARY_FONT,measure_fonts
    items=load(OUT/'verses.json')['items'];fontpath=ROOT/PRIMARY_FONT
    headings=load(OUT/'surah_titles_diyanet.json')['items']
    chars={c for v in items for c in v['text'] if not c.isspace()}
    assert len(headings)==114
    heading_runs=['سُورَةُ '+h['name'] for h in headings]
    chars.update(c for text in heading_runs for c in text if not c.isspace())
    with TTFont(fontpath) as f:cmap=f.getBestCmap()
    missing=sorted(f'U+{ord(c):04X}' for c in chars if ord(c) not in cmap)
    font=hb.Font(hb.Face(fontpath.read_bytes()));hb.ot_font_set_funcs(font)
    failures=[]
    for v in items:
        buf=hb.Buffer();buf.add_str(v['text']);buf.guess_segment_properties();hb.shape(font,buf)
        if any(g.codepoint==0 for g in buf.glyph_infos):failures.append(f"{v['surah']}:{v['ayah']}")
    heading_failures=[]
    for h,text in zip(headings,heading_runs):
        buf=hb.Buffer();buf.add_str(text);buf.guess_segment_properties();hb.shape(font,buf)
        if any(g.codepoint==0 for g in buf.glyph_infos):heading_failures.append(h['surah'])
    report={'primaryFont':PRIMARY_FONT,'fontSha256':sha(fontpath),'primaryMissingCodepoints':missing,'shapingMissingGlyphVerses':failures,'shapedVerseCount':len(items),'headingPrefix':'سُورَةُ ','shapedHeadingCount':len(headings),'shapingMissingGlyphHeadings':heading_failures,'headingDatasetSha256':sha(OUT/'surah_titles_diyanet.json'),'requiredDistinctCodepoints':len(chars),'shaper':'HarfBuzz, default Arabic script shaping, complete unchanged verse and prefixed heading runs','caveat':'Zero .notdef glyphs and cmap coverage do not prove visual diacritic placement or device rendering. Human visual/device review remains required.',**measure_fonts(items)}
    meal_chars={c for name in ('translations','footnotes','surah_descriptions','surah_names_pdf') for item in load(OUT/f'{name}.json')['items'] for key in ('text','name') for c in item.get(key,'') if not c.isspace()}
    meal_fonts=[]
    for path in sorted((ROOT/'assets/fonts').glob('NotoSerif*.ttf')):
        with TTFont(path) as f: meal_cmap=f.getBestCmap()
        meal_fonts.append({'path':str(path.relative_to(ROOT)),'sha256':sha(path),'requiredDistinctCodepoints':len(meal_chars),'missingCodepoints':sorted(f'U+{ord(c):04X}' for c in meal_chars if ord(c) not in meal_cmap)})
    report['turkmenFonts']=meal_fonts
    save(SRC/'full-font-validation.json',report)
    assert len(meal_fonts)==2 and all(not f['missingCodepoints'] for f in meal_fonts)
    assert not missing and not failures and not heading_failures,(missing,failures[:10],heading_failures)
    print('Font primary coverage and HarfBuzz',len(items),'verses and',len(headings),'prefixed headings PASS',flush=True)

def validate_pdf_pages():
    import pymupdf
    from collections import Counter
    path=Path('/home/gadamgurban/Documents/kurani-kerim-turkce.pdf')
    doc=pymupdf.open(path);pages=load(OUT/'pages.json')['items'];checks=[];failures=[]
    for page in pages:
        text=doc[page['pdfPage']-1].get_text()
        markers=[ord(c)-769 for c in text if 770<=ord(c)<=1055]
        expected=[v['ayah'] for v in page['verses']]
        ok=Counter(markers)==Counter(expected)
        record={'sourcePage':page['printedPage'],'pdfPage':page['pdfPage'],'expectedAyahNumbers':expected,'extractedCidMarkerNumbers':markers,'matches':ok}
        checks.append(record)
        if not ok:failures.append(page['printedPage'])
    save(SRC/'full-pdf-page-validation.json',{'pdfPath':str(path),'pdfSha256':sha(path),'physicalPageCount':len(doc),'checkedPages':len(checks),'mismatchingSourcePages':failures,'method':'Compare multiset of CID marker values codepoint minus 769 with official source page ayah numbers. Glyph-to-Unicode Arabic identity is not claimed; no full visual review is claimed.','pages':checks})
    print('PDF markers',len(checks)-len(failures),'PASS;',len(failures),'mismatch',failures[:30],flush=True)

def write_manifest():
    files=sorted(OUT.glob('*.json'))+[SRC/name for name in ('editorial-approvals.json','full-translation-anomalies.json','full-translation-conservation.json','full-font-validation.json','full-pdf-page-validation.json','full-turkmen-pdf-extraction-validation.json','diyanet-reading/manifest.json','diyanet-reading/surahs-decoded.json','diyanet-reading/surahs-response.json','diyanet-reading/isaretciler-response.json','diyanet-reading/isaretciler-decoded.json','diyanet-reading/public-client.js','pdf-extraction/all-pages.json')]
    save(SRC/'full-content-manifest.json',{'status':'complete-source-datasets','releaseApproval':'pending-final-device-and-store-release-review' if not pending_mapping_reviews() else 'pending-human-source-and-device-review','humanReviewRequired':pending_mapping_reviews(),'scope':'114 surahs; 6236 exact official textGroup 4 ayahs; 605 separate official source pages; full source translation paragraphs, introductions and notes','counts':{p.stem:len(load(p)['items']) for p in sorted(OUT.glob('*.json'))},'sourceCaptureCount':605,'sourceVerseCount':6236,'permissions':'User explicitly asserted complete source permissions on 2026-11-13. This is a recorded assertion, not an independently verified license.','normalization':'Arabic: none. Türkmen: whitespace folding and retained lexical line-end hyphens; pre-existing Fatiha soraýa- / rys joining only. Unicode never normalized or stripped.','artifactHashes':{str(p.relative_to(ROOT)):sha(p) for p in files},'rebuild':'/tmp/quran-data-venv/bin/python tools/build_full_content.py (requires pymupdf, fonttools, uharfbuzz)','validationCaveats':['PDF CID marker multiset checks verify numerical boundaries, not complete Arabic glyph/Unicode identity.','HarfBuzz zero-notdef checks are not visual/device approval.','Unprinted source verse label 79:41 explicitly mapped with preceding unchanged paragraph; sourceLabel remains 40.','Line-end hyphenation beyond pre-existing reviewed soraýa-rys is preserved conservatively, not lexically guessed.']})

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--capture',action='store_true');args=parser.parse_args()
    if args.capture:capture()
    else:
        from check_full_content import verify_translation_conservation
        from build_sajdah_markers import build as build_sajdah_markers
        build_titles_metadata();build_arabic();build_translations();validate_fonts();validate_pdf_pages();verify_translation_conservation();build_sajdah_markers();write_manifest()
