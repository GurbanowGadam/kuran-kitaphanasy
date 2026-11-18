#!/usr/bin/env python3
"""One-time identity migration; deliberately touches native/web scaffolds only."""
from pathlib import Path
import plistlib
ROOT = Path(__file__).resolve().parents[2]
old = ROOT / 'android/app/src/main/kotlin/tm/demo/kurany_kerim_demo/MainActivity.kt'
new = ROOT / 'android/app/src/main/kotlin/tm/kuran/kitaphanasy/MainActivity.kt'
if old.exists():
    new.parent.mkdir(parents=True, exist_ok=True)
    new.write_text(old.read_text().replace('tm.demo.kurany_kerim_demo', 'tm.kuran.kitaphanasy'))
    old.unlink()
p = ROOT / 'ios/Runner/Info.plist'
info = plistlib.loads(p.read_bytes())
info.update(CFBundleDisplayName='Kuran Kitaphanasy', CFBundleName='Kuran Kitaphanasy',
            CFBundleDevelopmentRegion='tk', CFBundleLocalizations=['tk', 'ar', 'en'],
            ITSAppUsesNonExemptEncryption=False)
p.write_bytes(plistlib.dumps(info, sort_keys=False))
p = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
s = p.read_text().replace('developmentRegion = en;', 'developmentRegion = tk;')
s = s.replace('knownRegions = (\n\t\t\t\ten,', 'knownRegions = (\n\t\t\t\ttk,\n\t\t\t\tar,\n\t\t\t\ten,')
p.write_text(s)
p = ROOT / 'web/index.html'
s = p.read_text().replace('<html>', '<html lang="tk">').replace('kurany_kerim_demo', 'Kuran Kitaphanasy')
s = s.replace('Kurany Kerim — Türkmençe', 'Kuran Kitaphanasy')
s = s.replace('Türkmençe Kurany Kerim — ýerli synag nusgasy.', 'Kurany Kerim we türkmençe many terjimesi. Tor bolmasa-da okap bolýar.')
p.write_text(s)
p = ROOT / '.gitignore'
s = p.read_text()
if '/android/key.properties' not in s:
    p.write_text(s + '\n# Private release credentials and local tooling\n/android/key.properties\n*.jks\n*.keystore\n*.p12\n*.mobileprovision\n.venv*/\n__pycache__/\n')
