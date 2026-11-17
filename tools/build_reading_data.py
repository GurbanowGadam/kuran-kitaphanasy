#!/usr/bin/env python3
"""Build PDF-derived datasets without inventing text or Diyanet boundaries.
Run extract_pdf_sources.py first. Live Arabic/page retrieval was blocked.
"""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/data'; OUT.mkdir(parents=True,exist_ok=True)
RAW=ROOT/'assets/sources/pdf-extraction/all-pages.json'
PAGES=json.loads(RAW.read_text())
PDF=Path('/home/gadamgurban/Documents/kurany_kerim_turkmen_dilinde.pdf')
def clean(s):
    # The only discretionary (non-lexical) hyphen in this selected excerpt.
    s=s.replace('soraýa-\nrys','soraýarys')
    s=re.sub(r'-\s*\n\s*','-',s)
    return ' '.join(s.split())
PDF_SOURCE={'type':'user-provided-pdf','path':str(PDF),'sha256':hashlib.file_digest(PDF.open('rb'),'sha256').hexdigest(),'pageNumbering':'1-based physical PDF page; printed PDF numbers coincide in this excerpt','extraction':'tools/extract_pdf_sources.py; text blocks in left-then-right column order','normalization':'Whitespace joined; lexical line-end hyphens retained without whitespace; soraýa- / rys joined. No translation or spelling corrections.','redistribution':'Not established; local prototype only.'}
def write(name,items,source):
    (OUT/f'{name}.json').write_text(json.dumps({'source':source,'items':items},ensure_ascii=False,indent=2)+'\n')
# Titles, including meanings that continue on the next physical text line.
names=[]
for page in PAGES:
    for side in ('left','right'):
        lines=page[side].splitlines()
        for i,line in enumerate(lines):
            m=re.match(r'^(\d+)-(?:nji|njy) süre:\s*(.*)$',line)
            if m:
                n=int(m[1]); title=m[2]; heading=line
                if i+1<len(lines) and lines[i+1].startswith('('):
                    heading+=' '+lines[i+1]; title+=' '+lines[i+1]
            elif line=='52-nji: «Tur» süresi':
                n=52; title='«Tur»'; heading=line
            else: continue
            display=re.sub(r'\s*\([^()]*\)\s*$','',title).strip(' «»')
            names.append({'surah':n,'name':display,'originalHeading':heading,'pdfPage':page['pdfPage']})
names.sort(key=lambda x:x['surah'])
assert [x['surah'] for x in names]==list(range(1,115))
write('surah_names_pdf',names,PDF_SOURCE)
# Editorial pronunciation-oriented rendering: NOT the PDF's meaning/alias list.
phonetic='''El-Fätiha|El-Bakara|Älu Ymran|En-Nisä|El-Mäide|El-Engäm|El-Agräf|El-Enfäl|Et-Tewbe|Ýunus|Hud|Ýusuf|Er-Ragd|Ybrahym|El-Hijr|En-Nahl|El-Isrä|El-Kehf|Merýem|Taha|El-Enbiýä|El-Hajj|El-Mu’minun|En-Nur|El-Furkan|Eş-Şu’arä|En-Neml|El-Kasas|El-Ankebut|Er-Rum|Lukman|Es-Sejde|El-Ahzäb|Sebe|Fätyr|Ýäsin|Es-Säffät|Sad|Ez-Zümer|Gäfir|Fussilet|Eş-Şura|Ez-Zuhruf|Ed-Duhän|El-Jäsiýe|El-Ahkaf|Muhammed|El-Feth|El-Hujurät|Kaf|Ez-Zäriýät|Et-Tur|En-Nejm|El-Kamar|Er-Rahmän|El-Wäky’a|El-Hadid|El-Mujädele|El-Haşr|El-Mumtehine|Es-Saff|El-Jumu’a|El-Munäfikun|Et-Tegabun|Et-Taläk|Et-Tahrim|El-Mulk|El-Kalem|El-Häkka|El-Me’ärij|Nuh|El-Jinn|El-Muzzemmil|El-Muddessir|El-Kyýäme|El-Insän|El-Murselät|En-Nebe|En-Näzi’ät|Abese|Et-Tekwir|El-Infitär|El-Mutaffifin|El-Inşikak|El-Buruj|Et-Täryk|El-A’lä|El-Gaşiýe|El-Fejr|El-Beled|Eş-Şems|El-Leýl|Ed-Duhä|Eş-Şerh|Et-Tin|El-Alak|El-Kadr|El-Beýýine|Ez-Zelzele|El-Ädiýät|El-Käri’a|Et-Tekäsur|El-Asr|El-Humeze|El-Fil|Kuraýş|El-Mä’un|El-Kewser|El-Käfirun|En-Nasr|El-Mesed|El-Ihläs|El-Felak|En-Näs'''.split('|')
assert len(phonetic)==114
write('surah_names_arabic',[{'surah':i,'name':s} for i,s in enumerate(phonetic,1)],{'type':'editorial-transliteration','language':'Turkmen-oriented Latin phonetic approximation','authority':'Editorial, not sourced from Diyanet or PDF; not a scholarly transliteration standard. Human Arabic/Turkmen review required.','note':'Pronunciation names, not translated meanings. Surah 40 uses Gafir and 94 uses Sharh rather than the PDF aliases.'})
translations=[]; footnotes=[]; descriptions=[]
# The selected ten PDF reading pages end at Bakara 69. Do not claim verified mushaf coverage.
for surah,start,end in [(1,2,2),(2,3,11)]:
    text=''; spans=[]
    for page in PAGES[start-1:end]:
        chunk=page['left']+'\n'+page['right']+'\n'
        spans.append((len(text),len(text)+len(chunk),page['pdfPage']))
        text+=chunk
    def pdfpage(pos): return next(p for a,b,p in spans if a<=pos<b)
    markers=list(re.finditer(r'(?m)^(\d+(?:,\s*\d+)*)\.\s*',text))
    intro=text[:markers[0].start()]
    intro=intro.split('\n',1)[1]
    if surah==2: intro=intro[:intro.index('Rahman (Mähriban)')]
    descriptions.append({'surah':surah,'text':clean(intro),'pdfPage':start})
    for k,m in enumerate(markers):
        numbers=[int(n) for n in re.findall(r'\d+',m[1])]
        endpos=markers[k+1].start() if k+1<len(markers) else len(text)
        body=text[m.end():endpos]
        parts=body.split('Düşündiriş:')
        item={'id':f'{surah}:{numbers[0]}-{numbers[-1]}','surah':surah,'fromAyah':numbers[0],'toAyah':numbers[-1],'text':clean(parts[0]),'footnoteIds':[],'pdfPage':pdfpage(m.start())}
        offset=m.end()+len(parts[0])
        for j,note in enumerate(parts[1:],1):
            fid=f'{surah}:{numbers[0]}-{numbers[-1]}:note-{j}'
            footnotes.append({'id':fid,'surah':surah,'fromAyah':numbers[0],'toAyah':numbers[-1],'text':'Düşündiriş: '+clean(note),'pdfPage':pdfpage(offset)})
            item['footnoteIds'].append(fid)
            offset+=len('Düşündiriş:')+len(note)
        translations.append(item)
assert [(t['surah'],t['fromAyah']) for t in translations]==[(1,a) for a in range(1,8)]+[(2,a) for a in range(1,70)]
write('translations',translations,PDF_SOURCE)
write('surah_descriptions',descriptions,PDF_SOURCE)
write('footnotes',footnotes,{**PDF_SOURCE,'linking':'Each Düşündiriş paragraph linked to the immediately preceding source verse/group. The final Fatiha note concerns saying Amin after the surah and is anchored to verse 7.'})
# Do not let this legacy translation builder erase completed Arabic/pagination.
# Rebuild those separately with complete_reading_data.py and frozen captures.
if (OUT/'pages.json').exists() and json.loads((OUT/'pages.json').read_text()).get('items'):
    print('Translation datasets rebuilt; existing completed pages, verses and manifest preserved.')
    raise SystemExit(0)
# Explicitly blocked, never fabricate official pagination or missing Arabic.
block={'type':'diyanet-api','baseUrl':'https://kuran.diyanet.gov.tr/api/v2','status':'blocked-incomplete','reason':'Live requests returned 403 / security-rule HTML. Further network attempt denied. No official page responses available; page boundaries must not be guessed.','requiredCoverage':'10 reading pages beginning with Fatiha; anticipated 0..9 is NOT verified','existingVerifiedArabic':'assets/sources/arabic-verified.json (previous verified exact textGroup 4 records)'}
write('pages',[],block)
existing=json.loads((ROOT/'assets/sources/arabic-verified.json').read_text())
verses=[{'surah':v['surah'],'ayah':v['ayah'],'text':v['arabic']} for v in existing if v['surah'] in (1,2)]
write('verses',verses,{**block,'availableCoverage':'Fatiha 1-7, Bakara 1-5 ONLY; incomplete for ten pages','textGroup':4})
manifest={'status':'blocked-incomplete','pdf':PDF_SOURCE,'datasets':{p.stem:len(json.loads(p.read_text())['items']) for p in OUT.glob('*.json')},'verifiedPdfCoverage':'Fatiha 1-7; Bakara 1-69 (ten PDF reading pages 2-11)','verifiedDiyanetPages':[],'unresolved':['Authoritative Diyanet page 0..9 verification and exact API Arabic for Bakara 6 onward','Page-boundary/group crossing checks cannot run without official pages','Human review of editorial Arabic-name transliteration and redistribution permission'], 'normalizationExceptions':[{'source':'soraýa-\nrys','output':'soraýarys','location':'Fatiha 5, PDF page 2'}],'reproduce':['python3 -m venv /tmp/quran-data-venv','/tmp/quran-data-venv/bin/pip install pymupdf','/tmp/quran-data-venv/bin/python tools/extract_pdf_sources.py','python3 tools/build_reading_data.py','python3 tools/check_reading_data.py']}
(ROOT/'assets/sources/reading-data-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(manifest['datasets'],ensure_ascii=False)); print('BLOCKED: ten-page official Arabic/pagination incomplete; PDF extraction complete to 2:69.')
