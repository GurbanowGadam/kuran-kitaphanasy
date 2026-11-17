import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
translations = json.loads((ROOT/'test/translation_expected.json').read_text())
arabic = json.loads((ROOT/'assets/sources/arabic-verified.json').read_text())
surahs = []
for sid, name, subtitle in [(1,'Fatyha','Açylyş · 7 aýat · Mekge'),(2,'Bakara','Sygyr · 1–5-nji aýatlar · Medine'),(112,'Yhlas','Kulhuwalla · 4 aýat · Mekge')]:
    verses = [v for v in arabic if v['surah'] == sid]
    assert len(verses) == {1:7,2:5,112:4}[sid]
    blocks = []
    for index, translation in enumerate(translations[str(sid)]):
        chosen = verses if sid == 112 else [verses[index]]
        blocks.append({'range':'1–4' if sid == 112 else str(index+1), 'arabic':'\n'.join(v['arabic'] for v in chosen), 'translation':translation})
    surahs.append({'id':sid,'name':name,'subtitle':subtitle,'blocks':blocks})
(ROOT/'assets/quran.json').write_text(json.dumps({'surahs':surahs},ensure_ascii=False,indent=2)+'\n')
print('Built 3 surahs, 13 translation blocks, 16 sourced Arabic verses.')
