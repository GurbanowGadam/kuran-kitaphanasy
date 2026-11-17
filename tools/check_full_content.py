#!/usr/bin/env python3
"""Independent full-edition verifier; offline, stdlib except optional font rebuild."""
import hashlib,json,re,subprocess,sys
from pathlib import Path
from editorial_review import pending_mapping_reviews
ROOT=Path(__file__).resolve().parents[1]
def load(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify_translation_conservation():
    """Reassemble source chapter bodies from output records, without calling the parser."""
    data={n:load(ROOT/f'assets/data/{n}.json')['items'] for n in ('translations','surah_descriptions','surah_names_pdf','footnotes')}
    raw=load(ROOT/'assets/sources/pdf-extraction/all-pages.json')
    original='\n'.join(p[side] for p in raw for side in ('left','right'))
    headings=list(re.finditer(r'(?m)^\d+-(?:nji|njy) süre:.*$|^52-nji: «Tur» süresi$',original))
    assert len(headings)==114
    def compact(s):return re.sub(r'\s+','',s.replace('soraýa-\nrys','soraýarys'))
    def digest(s):return hashlib.sha256(s.encode()).hexdigest()
    notes={n['id']:n for n in data['footnotes']};checks=[]
    for i,h in enumerate(headings):
        surah=i+1;body=original[h.start():headings[i+1].start() if i+1<len(headings) else len(original)]
        assembled=data['surah_names_pdf'][i]['originalHeading']+data['surah_descriptions'][i]['text']
        if surah not in (1,9):assembled+='Rahman (Mähriban) we Rahym (Rehim-şepagatly) Allanyň ady bilen'
        rows=[t for t in data['translations'] if t['surah']==surah]
        for t in rows:
            assembled+=t['sourceMarker']+t['text']+''.join(notes[n]['text'] for n in t['footnoteIds'])
        a,b=compact(body),compact(assembled)
        checks.append({'surah':surah,'translationBlocks':len(rows),'sourceCharacterCount':len(a),'reconstructedCharacterCount':len(b),'sourceSha256':digest(a),'reconstructedSha256':digest(b),'matches':a==b})
    failures=[s['surah'] for s in checks if not s['matches']]
    report={'method':'Independent reassembly of headings, descriptions, opening formulas, original numeric sourceMarkers, grouped translation paragraphs and all linked notes. Comparison ignores whitespace only plus the pre-existing reviewed Fatiha soraýa- / rys joining. No Unicode normalization or spelling correction. This does not prove human approval of verse interpretation.',
        'extractionSha256':sha(ROOT/'assets/sources/pdf-extraction/all-pages.json'),
        'datasetHashes':{n:sha(ROOT/f'assets/data/{n}.json') for n in data},'surahs':checks,'mismatchingSurahs':failures,
        'humanReviewRequired':pending_mapping_reviews()}
    (ROOT/'assets/sources/full-translation-conservation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    assert not failures,failures
    print('Independent translation source conservation',len(checks),'surahs PASS; editorial mapping review ' + ('pending' if report['humanReviewRequired'] else 'approved by product owner'),flush=True)
    return report

def verify():
    from capture_diyanet_reading import decode
    manifest=load(ROOT/'assets/sources/full-content-manifest.json')
    for path,digest in manifest['artifactHashes'].items():assert sha(ROOT/path)==digest,path
    from build_sajdah_markers import build_document
    assert load(ROOT/'assets/data/sajdah_markers.json') == build_document()
    print('PASS: 14 sajdah annotations match frozen official marker capture and source pages.')
    capture=load(ROOT/'assets/sources/diyanet-reading/manifest.json')
    js=ROOT/'assets/sources/diyanet-reading/public-client.js'
    assert sha(js)==capture['publicClientSha256']
    key=re.search(rb'const \w+="([0-9a-f]{64})";let \w+=null;function',js.read_bytes())[1].decode()
    verses=load(ROOT/'assets/data/verses.json')['items'];pages=load(ROOT/'assets/data/pages.json')['items']
    expected=[]
    assert len(capture['captures'])==605
    for n,c in enumerate(capture['captures']):
        raw=(ROOT/c['responsePath']).read_bytes();decoded=(ROOT/c['path']).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==c['responseSha256']
        assert hashlib.sha256(decoded).hexdigest()==c['sha256']
        assert decode(raw,key)==decoded,('public-client raw/decoded mismatch',n)
        rows=json.loads(decoded)['data']; members=[]
        assert c['count']==len(rows)
        for row in rows:
            assert row['sayfa']==n
            texts=[t['metin'] for t in row['metinler'] if t['metin_grubu_id']==4];assert len(texts)==1
            member={'surah':row['sure_id'],'ayah':row['ayet_no']};members.append(member);expected.append({**member,'text':texts[0]})
        assert members==pages[n]['verses']
    assert expected==verses and len(verses)==6236
    notes=load(ROOT/'assets/data/footnotes.json')['items']; note_ids={n['id'] for n in notes};used=[]
    translations=load(ROOT/'assets/data/translations.json')['items']
    for t in translations:
        assert t['text'] and 'Düşündiriş:' not in t['text']
        used+=t['footnoteIds']
    assert len(used)==len(note_ids)==203 and set(used)==note_ids
    raw=load(ROOT/'assets/sources/pdf-extraction/all-pages.json')
    assert sum(p[s].count('Düşündiriş:') for p in raw for s in ('left','right'))==len(notes)
    metadata=load(ROOT/'assets/sources/diyanet-reading/surahs-decoded.json')['data']
    titles=load(ROOT/'assets/data/surah_titles_diyanet.json');opening=load(ROOT/'assets/data/surah_metadata.json')
    for obj in (titles,opening):
        source=obj['source']
        assert sha(ROOT/source['decodedPath'])==source['decodedSha256']
        assert sha(ROOT/source['responsePath'])==source['responseSha256']
        assert decode((ROOT/source['responsePath']).read_bytes(),key)==(ROOT/source['decodedPath']).read_bytes()
    assert titles['items']==[{'surah':r['id'],'name':r['ad_ar']} for r in metadata]
    assert opening['items']==[{'surah':r['id'],'verseCount':r['ayet_sayisi'],'place':{'mekki':'Mekge','medeni':'Medine'}[r['inis_yeri']]} for r in metadata]
    assert len(titles['items'])==114
    fonts=load(ROOT/'assets/sources/full-font-validation.json')
    assert fonts['headingDatasetSha256']==sha(ROOT/'assets/data/surah_titles_diyanet.json')
    assert fonts['shapedHeadingCount']==114 and not fonts['shapingMissingGlyphHeadings']
    extraction=load(ROOT/'assets/sources/full-turkmen-pdf-extraction-validation.json')
    assert extraction['extractionSha256']==sha(ROOT/'assets/sources/pdf-extraction/all-pages.json')
    assert extraction['checkedColumns']==1210 and not extraction['mismatches']
    assert sha(Path(extraction['pdfPath']))==extraction['pdfSha256']
    verify_translation_conservation()
    subprocess.run([sys.executable,str(ROOT/'test/content_full_dataset.py')],check=True)
    print('PASS: 605 frozen public responses decoded and SHA-256 verified; all 6236 official textGroup 4 strings unchanged; full ordered Arabic/translation coverage; all 203 notes linked; all 114 surah bodies character-conserved.')
    return {'captures':605,'ayahs':6236,'translationBlocks':len(translations),'footnotes':len(notes)}
def poppler_columns(pdf, n):
    """Full-page Poppler bounding boxes: do not crop low body baselines at y=742."""
    import xml.etree.ElementTree as ET
    ns={'x':'http://www.w3.org/1999/xhtml'}
    tree=ET.fromstring(subprocess.check_output(['pdftotext','-f',str(n),'-l',str(n),'-bbox-layout',str(pdf),'-']))
    split=255 if n%2==0 else 287
    columns={};geometry={}
    for side in ('left','right'):
        lines=[];geometry[side]=[]
        for line in tree.findall('.//x:line',ns):
            words=[w for w in line.findall('x:word',ns)
                   if (float(w.attrib['xMin'])<split)==(side=='left')
                   and not ((w.text or '').isdigit() and float(w.attrib['yMin'])>740)]
            if words:
                text=' '.join(w.text or '' for w in words)
                lines.append((float(line.attrib['yMin']),float(line.attrib['xMin']),text))
                geometry[side].append({'yMin':min(float(w.attrib['yMin']) for w in words),'yMax':max(float(w.attrib['yMax']) for w in words),'text':text})
        columns[side]='\n'.join(t[2] for t in sorted(lines))
    columns['_geometry']=geometry
    return columns

def verify_pdf_extraction():
    from concurrent.futures import ThreadPoolExecutor
    pdf=Path('/home/gadamgurban/Documents/kurany_kerim_turkmen_dilinde.pdf')
    raw=load(ROOT/'assets/sources/pdf-extraction/all-pages.json')
    def compact(t):return re.sub(r'\s+','',t)
    def one(n):
        import difflib
        columns=poppler_columns(pdf,n); mismatches=[]; crop_issues=[]
        for side in ('left','right'):
            expected=compact(raw[n-1][side]);actual=compact(columns[side])
            if actual!=expected:
                mismatches.append({'pdfPage':n,'column':side,'popplerCharacters':len(actual),'pymupdfCharacters':len(expected),
                    'differences':[{'operation':tag,'poppler':actual[i:j],'pymupdf':expected[k:l]} for tag,i,j,k,l in difflib.SequenceMatcher(None,actual,expected,autojunk=False).get_opcodes() if tag!='equal']})
            # Reproduce the superseded check to retain independently inspectable evidence.
            split=255 if n%2==0 else 287;x,w=(0,split) if side=='left' else (split,539-split)
            old=compact(subprocess.check_output(['pdftotext','-f',str(n),'-l',str(n),'-x',str(x),'-y','0','-W',str(w),'-H','742','-layout',str(pdf),'-']).decode())
            if old!=expected:
                differences=[{'operation':tag,'croppedPoppler':old[i:j],'frozenPymupdf':expected[k:l]} for tag,i,j,k,l in difflib.SequenceMatcher(None,old,expected,autojunk=False).get_opcodes() if tag!='equal']
                crop_issues.append({'pdfPage':n,'column':side,'croppedPopplerCharacters':len(old),'pymupdfCharacters':len(expected),'fullPagePopplerMatches':actual==expected,'lowBodyLines':[line for line in columns['_geometry'][side] if line['yMax']>742],'differences':differences})
        return mismatches,crop_issues
    with ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(one,range(2,607)))
    mismatches=[m for ms,_ in results for m in ms];crop_issues=[m for _,ms in results for m in ms]
    report={'pdfPath':str(pdf),'pdfSha256':sha(pdf),'extractionSha256':sha(ROOT/'assets/sources/pdf-extraction/all-pages.json'),'checkedColumns':1210,'physicalPdfPages':[2,606],
        'method':'Independent full-page Poppler -bbox-layout words grouped by xMin at mirrored 255/287pt gutter, lines sorted by yMin/xMin. Exclude only numeric footer words yMin>740. Compare to frozen PyMuPDF, ignoring whitespace only; Unicode, spelling, punctuation and hyphens unchanged.',
        'popplerVersion':subprocess.run(['pdftotext','-v'],capture_output=True,text=True,check=True).stderr.splitlines()[0],
        'supersededCropHeight':742,'supersededCropMismatches':crop_issues,
        'diagnosis':'Old -H 742 crop omitted low body lines, NOT PyMuPDF text loss. Full-page independent extraction is checked without truncating body baselines. Every original discrepancy is reproduced below, including exact omitted strings. No canonical text or frozen PyMuPDF extraction was changed.',
        'mismatches':mismatches}
    path=ROOT/'assets/sources/full-turkmen-pdf-extraction-validation.json';path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('Independent Türkmen PDF columns',1210,'mismatches',len(mismatches),'superseded crop discrepancies',len(crop_issues),flush=True)
    assert not mismatches,mismatches[:10]
if __name__=='__main__':
    if '--pdf-extraction' in sys.argv:verify_pdf_extraction()
    elif '--translation-conservation' in sys.argv:verify_translation_conservation()
    else:verify()
