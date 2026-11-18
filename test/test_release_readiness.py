"""Offline release checks using isolated fixtures; never read owner signing files."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_readiness', REPO / 'tool/release_readiness.py')
assert spec is not None and spec.loader is not None
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class ReleaseReadinessTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        # Deliberately do not copy android/key.properties, keystores or local env.
        files = [
            'android/app/build.gradle.kts', 'ios/Runner/Info.plist',
            'ios/Runner.xcodeproj/project.pbxproj',
            'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
            'assets/branding/generated-icons.json',
            'assets/branding/auto_stories_outlined.path',
            'assets/branding/app-icon.svg', 'web/manifest.json', 'web/index.html',
        ]
        files += list(json.loads((REPO / 'assets/branding/generated-icons.json').read_text()))
        files += ['web/' + icon['src'] for icon in json.loads((REPO / 'web/manifest.json').read_text())['icons']]
        for name in files:
            dest = self.root / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / name, dest)
        shutil.copytree(REPO / 'android/app/src', self.root / 'android/app/src', dirs_exist_ok=True)
        self.version('1.0.0+3')

    def version(self, value):
        (self.root / 'pubspec.yaml').write_text('name: fixture\nversion: ' + value + '\n')

    def run_check(self, *args, env=None):
        output = io.StringIO()
        with patch.object(validator, 'ROOT', self.root), patch('sys.argv', ['release_readiness.py', *args]), patch.dict(os.environ, env or {}, clear=True), contextlib.redirect_stdout(output):
            validator.main()
        return output.getvalue()

    def edit(self, name, old, new):
        path = self.root / name
        path.write_text(path.read_text().replace(old, new))

    def test_download_first_release_passes(self):
        output = self.run_check()
        self.assertIn('Version: 1.0.0+3 verified', output)
        self.assertIn('UNSIGNED release; debug signing is isolated', output)

    def test_stable_release_versions(self):
        for version in ('1.0.0+1', '2.12.34+42', '0.1.0+3'):
            with self.subTest(version=version):
                self.version(version)
                self.assertIn('Version: ' + version + ' verified', self.run_check())

    def test_invalid_versions_are_rejected_even_with_pending_flag(self):
        for version in ('', '1.0', '1.0.0', '1.0.0+0', '1.0.0+-1', '1.0.0+abc', '01.0.0+3', '1.0.0+03', '1.0.0-rc.1+3', '1.0.0+3 extra'):
            for args in ((), ('--allow-pending-version',)):
                with self.subTest(version=version, args=args):
                    self.version(version)
                    with self.assertRaisesRegex(ValueError, 'pubspec version'):
                        self.run_check(*args)

    def test_missing_internet_is_rejected(self):
        self.edit('android/app/src/main/AndroidManifest.xml', '<uses-permission android:name="android.permission.INTERNET" />', '')
        with self.assertRaisesRegex(ValueError, 'INTERNET'):
            self.run_check()

    def test_sensitive_permissions_in_source_manifests_are_rejected(self):
        for source in ('main', 'release', 'profile', 'debug'):
            for tag in ('uses-permission', 'uses-permission-sdk-23'):
                with self.subTest(source=source, tag=tag):
                    path = self.root / f'android/app/src/{source}/AndroidManifest.xml'
                    original = path.read_text() if path.exists() else None
                    path.parent.mkdir(parents=True, exist_ok=True)
                    content = original or '<manifest xmlns:android="http://schemas.android.com/apk/res/android"></manifest>'
                    path.write_text(content.replace('</manifest>', f'<{tag} android:name="android.permission.RECORD_AUDIO" /></manifest>'))
                    with self.assertRaisesRegex(ValueError, 'Unexpected source-manifest permission'):
                        self.run_check()
                    if original is None:
                        path.unlink()
                    else:
                        path.write_text(original)

    def test_missing_signing_is_rejected_when_required(self):
        with self.assertRaisesRegex(ValueError, 'Owner release signing credentials are required'):
            self.run_check('--require-signing')

    def test_partial_signing_env_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Incomplete signing configuration'):
            self.run_check(env={'ANDROID_KEYSTORE_PATH': 'absent-fixture-file'})

    def test_partial_signing_properties_is_rejected(self):
        (self.root / 'android/key.properties').write_text('storeFile=absent-fixture-file\n')
        with self.assertRaisesRegex(ValueError, 'Incomplete signing configuration'):
            self.run_check()

    def test_signing_cannot_bypass_version_gate(self):
        with self.assertRaisesRegex(ValueError, 'cannot bypass the version gate'):
            self.run_check('--require-signing', '--allow-pending-version')

    def test_existing_protections_are_retained(self):
        cases = (
            ('android/app/build.gradle.kts', 'else null', 'else signingConfigs.getByName("debug")', 'Release must not use debug key'),
            ('android/app/build.gradle.kts', 'namespace = "tm.kuran.kitaphanasy"', 'namespace = "invalid"', 'namespace'),
            ('android/app/src/main/AndroidManifest.xml', 'android:allowBackup="false"', 'android:allowBackup="true"', 'Android backup policy'),
            ('android/app/src/main/AndroidManifest.xml', 'android:exported="true"', 'android:exported="false"', 'Android 12 exported launcher'),
            ('web/index.html', '<title>Kuran Kitaphanasy</title>', '<title>Wrong</title>', 'Web title'),
        )
        for name, old, new, error in cases:
            with self.subTest(error=error):
                path = self.root / name
                original = path.read_text()
                self.assertIn(old, original)
                self.edit(name, old, new)
                with self.assertRaisesRegex(ValueError, error):
                    self.run_check()
                path.write_text(original)


if __name__ == '__main__':
    unittest.main()
