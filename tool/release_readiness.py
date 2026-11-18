#!/usr/bin/env python3
"""Offline, stdlib-only scaffold checks. NOT a compiler or store approval check."""
import argparse
import json
import os
import plistlib
import re
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'

def require(condition, message):
    if not condition:
        raise ValueError(message)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-signing', action='store_true')
    parser.add_argument('--allow-pending-version', action='store_true', help='Deprecated compatibility flag; invalid release versions are never accepted')
    args = parser.parse_args()
    require(not (args.require_signing and args.allow_pending_version), 'Signed release checks cannot bypass the version gate')
    gradle = (ROOT/'android/app/build.gradle.kts').read_text()
    for key in ('namespace', 'applicationId'):
        require(f'{key} = "tm.kuran.kitaphanasy"' in gradle, key)
    require('applicationIdSuffix = ".debug"' in gradle, 'Debug installation isolation')
    require('signingConfigs.getByName("debug")' not in gradle, 'Release must not use debug key')
    require('else null' in gradle, 'Unsigned release default missing')
    activity = ROOT/'android/app/src/main/kotlin/tm/kuran/kitaphanasy/MainActivity.kt'
    require('package tm.kuran.kitaphanasy' in activity.read_text(), 'Kotlin package')
    manifest = ET.parse(ROOT/'android/app/src/main/AndroidManifest.xml').getroot()
    require(any(p.get(ANDROID+'name') == 'android.permission.INTERNET' for p in manifest.findall('uses-permission')), 'Download-first audio requires INTERNET permission')
    # Source overlays can add permissions too. Merged plugin/artifact permissions
    # still need a separate release-artifact audit.
    for source in sorted((ROOT/'android/app/src').rglob('AndroidManifest.xml')):
        for permission in ET.parse(source).getroot():
            if permission.tag.startswith('uses-permission'):
                require(permission.get(ANDROID+'name') == 'android.permission.INTERNET',
                        'Unexpected source-manifest permission in '+str(source.relative_to(ROOT)))
    app = manifest.find('application')
    require(app.get(ANDROID+'label') == 'Kuran Kitaphanasy', 'Android display name')
    require(app.get(ANDROID+'allowBackup') == 'false', 'Android backup policy')
    require(app.find('activity').get(ANDROID+'exported') == 'true', 'Android 12 exported launcher')
    rules = ET.parse(ROOT/'android/app/src/main/res/xml/data_extraction_rules.xml').getroot()
    for category in ('cloud-backup', 'device-transfer'):
        domains = {e.get('domain') for e in rules.find(category)}
        require({'root','file','database','sharedpref','external','device_root','device_file','device_database','device_sharedpref'} <= domains, category+' exclusions')
    for xml in (ROOT/'android/app/src').rglob('*.xml'):
        ET.parse(xml)
    info = plistlib.loads((ROOT/'ios/Runner/Info.plist').read_bytes())
    require(info['CFBundleDisplayName'] == 'Kuran Kitaphanasy', 'iOS name')
    require(info['CFBundleLocalizations'] == ['tk', 'ar', 'en'], 'iOS locales')
    project = (ROOT/'ios/Runner.xcodeproj/project.pbxproj').read_text()
    require(project.count('PRODUCT_BUNDLE_IDENTIFIER = tm.kuran.kitaphanasy;') == 3, 'iOS Debug/Profile/Release bundle ID')
    for p in (ROOT/'ios').rglob('*.plist'):
        plistlib.loads(p.read_bytes())
    sizes = json.loads((ROOT/'assets/branding/generated-icons.json').read_text())
    for path, size in sizes.items():
        raw = (ROOT/path).read_bytes()
        require(raw[:8] == b'\x89PNG\r\n\x1a\n', path+' PNG signature')
        require(struct.unpack('>II', raw[16:24]) == (size, size), path+' dimensions')
        if path.startswith('ios/'):
            require(raw[25] == 2, path+' must be RGB without alpha')
    catalog = ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for icon in json.loads((catalog/'Contents.json').read_text())['images']:
        path = str((catalog/icon['filename']).relative_to(ROOT))
        expected = round(float(icon['size'].split('x')[0])*float(icon['scale'].rstrip('x')))
        require(sizes.get(path) == expected, 'iOS catalog '+path)
    require(any(path.startswith('ios/') and size == 1024 for path,size in sizes.items()), 'iOS marketing icon')
    outline = (ROOT/'assets/branding/auto_stories_outlined.path').read_text().strip()
    vector = ET.parse(ROOT/'android/app/src/main/res/drawable/ic_launcher_foreground.xml').getroot()
    require(vector.find('group/path').get(ANDROID+'pathData') == outline, 'Original Material glyph vector')
    require(outline in (ROOT/'assets/branding/app-icon.svg').read_text(), 'SVG outline')
    for api in (26,33):
        adaptive = ET.parse(ROOT/f'android/app/src/main/res/mipmap-anydpi-v{api}/ic_launcher.xml').getroot()
        require(adaptive.find('foreground').get(ANDROID+'drawable') == '@drawable/ic_launcher_foreground', 'Adaptive foreground reference')
    web = json.loads((ROOT/'web/manifest.json').read_text())
    require(web['name'] == 'Kuran Kitaphanasy', 'Web name')
    for icon in web['icons']:
        require((ROOT/'web'/icon['src']).is_file(), 'Web icon path')
    require('<title>Kuran Kitaphanasy</title>' in (ROOT/'web/index.html').read_text(), 'Web title')
    versions = re.findall(r'^version:[ \t]*([^\n]*)', (ROOT/'pubspec.yaml').read_text(), re.M)
    version = versions[0].split('#', 1)[0].strip() if len(versions) == 1 else ''
    require(re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\+[1-9][0-9]*', version),
            'pubspec version must be release MAJOR.MINOR.PATCH+positive Android version code')
    props_path = ROOT/'android/key.properties'
    props = {}
    if props_path.exists():
        for line in props_path.read_text().splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                key,value = line.split('=',1)
                props[key.strip()] = value.strip()
    names = [('storeFile','ANDROID_KEYSTORE_PATH'),('storePassword','ANDROID_KEYSTORE_PASSWORD'),('keyAlias','ANDROID_KEY_ALIAS'),('keyPassword','ANDROID_KEY_PASSWORD')]
    values = [os.getenv(env) or props.get(key) for key,env in names]
    require(all(values) or not any(values), 'Incomplete signing configuration')
    if all(values):
        path = Path(values[0])
        require((path if path.is_absolute() else ROOT/'android'/path).is_file(), 'Signing keystore path does not exist')
        signing = 'configured (certificate ownership and validity NOT checked)'
    else:
        signing = 'UNSIGNED release; debug signing is isolated'
    if args.require_signing:
        require(all(values), 'Owner release signing credentials are required')
    print(f'PASS: product identity, Android XML/export/backup policy, Kotlin path, iOS bundle IDs/plists/catalog, {len(sizes)} PNG dimensions, original glyph vectors, web manifest.')
    print('Version: '+version+' verified')
    print('Signing: '+signing)
    print('Not verified: Gradle/Xcode compilation, merged artifact permissions, device visuals, certificates, store policy or publication.')

if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, ET.ParseError) as error:
        print('FAIL: '+str(error), file=sys.stderr)
        sys.exit(1)
