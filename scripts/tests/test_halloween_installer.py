"""Exercise the scoped installer with Mac utilities substituted on Linux."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/install-halloween-update-macos.sh'
FILES = [
    'lib/seasonal/halloween_scene_v2.dart', 'lib/seasonal/halloween_motion.dart',
    'lib/seasonal/seasonal_scene_support.dart',
    *['assets/seasonal/halloween_v2/' + name + '.png' for name in [
        'background_tree_clear', 'tree_isolated', 'moon_cloud_clean', 'pumpkin_closed',
        'pumpkin_classic_light_mask', 'pumpkin_surprised_light_mask',
        'pumpkin_closed_light_mask', 'skeleton_eyes_closed_overlay']],
    'test/seasonal_scenes_test.dart', 'test/halloween_motion_test.dart',
    'test/halloween_scene_test.dart', 'test/halloween_assets_test.dart',
]
EXISTING = {FILES[0], 'test/seasonal_scenes_test.dart'}


class HalloweenInstallerTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='reczt-halloween-')
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.source, self.target = self.base / 'new source', self.base / 'working project'
        self.bin, self.backup = self.base / 'bin', self.base / 'backup'
        self.bin.mkdir()
        for name in FILES:
            self.write(self.source / name, 'new: ' + name)
            if name in EXISTING:
                self.write(self.target / name, 'old: ' + name)
        self.write(self.target / 'pubspec.yaml', 'flutter:\n  assets:\n    - assets/seasonal/halloween_v2/\n')
        (self.target / 'ios/Runner.xcworkspace').mkdir(parents=True)
        self.write(self.target / 'ios/Flutter/Generated.xcconfig', f'FLUTTER_APPLICATION_PATH={self.target}\n')
        self.protected = ['lib/main.dart', 'lib/seasonal/christmas_scene.dart',
            'assets/seasonal/christmas/christmas_background_clean.png',
            'ios/RecztControl/RecztRecognitionLiveActivity.swift',
            'ios/Pods/keep', 'ios/Runner.xcodeproj/project.pbxproj']
        for name in self.protected:
            self.write(self.target / name, 'preserve: ' + name)
        self.write(self.source / 'scripts' / SCRIPT.name, SCRIPT.read_text())
        self.stub('uname', '#!/bin/sh\necho Darwin\n')
        self.stub('mktemp', "#!/usr/bin/env python3\nimport os,pathlib\np=pathlib.Path(os.environ['RECZT_TEST_BACKUP']);p.mkdir();print(p)\n")
        self.stub('ditto', "#!/usr/bin/env python3\nimport pathlib,shutil,sys\na,b=map(pathlib.Path,sys.argv[1:]);b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(a,b)\n")
        self.stub('open', "#!/usr/bin/env python3\nimport os,pathlib,sys\npathlib.Path(os.environ['RECZT_TEST_OPEN']).write_text(sys.argv[1])\n")
        self.env = dict(os.environ, RECZT_TEST_BACKUP=str(self.backup), RECZT_TEST_OPEN=str(self.base / 'opened'))
        self.env['PATH'] = str(self.bin) + os.pathsep + os.environ['PATH']

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def stub(self, name, text):
        file = self.bin / name
        file.write_text(text)
        file.chmod(0o755)

    def install(self):
        return subprocess.run(['bash', str(self.source / 'scripts' / SCRIPT.name), str(self.target)], env=self.env, capture_output=True, text=True)

    def unchanged(self):
        for name in EXISTING:
            self.assertEqual((self.target / name).read_text(), 'old: ' + name)
        for name in self.protected:
            self.assertEqual((self.target / name).read_text(), 'preserve: ' + name)
        self.assertFalse((self.base / 'opened').exists())

    def test_installs_all_layers_and_backs_up_only_existing_files(self):
        config = (self.target / 'ios/Flutter/Generated.xcconfig').read_bytes()
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in FILES:
            self.assertEqual((self.target / name).read_text(), 'new: ' + name)
        for name in EXISTING:
            self.assertEqual((self.backup / name).read_text(), 'old: ' + name)
        self.assertEqual(set((self.backup / 'new-files.txt').read_text().splitlines()), set(FILES) - EXISTING)
        for name in self.protected:
            self.assertEqual((self.target / name).read_text(), 'preserve: ' + name)
        self.assertEqual((self.target / 'ios/Flutter/Generated.xcconfig').read_bytes(), config)
        self.assertEqual((self.base / 'opened').read_text(), str(self.target / 'ios/Runner.xcworkspace'))

    def test_missing_asset_aborts_before_modifying_the_project(self):
        (self.source / 'assets/seasonal/halloween_v2/tree_isolated.png').unlink()
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.unchanged()
        self.assertFalse(self.backup.exists())

    def test_installed_scene_contains_every_relative_dart_dependency(self):
        # Use the real libraries, rather than synthetic manifest contents, so
        # this catches a helper omitted from both the script and FILES above.
        for source in (ROOT / 'lib/seasonal').glob('*.dart'):
            self.write(self.source / 'lib/seasonal' / source.name, source.read_text())
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        pending = [self.target / 'lib/seasonal/halloween_scene_v2.dart']
        visited = set()
        while pending:
            source = pending.pop().resolve()
            if source in visited:
                continue
            self.assertTrue(source.is_file(), f'Missing installed dependency: {source.name}')
            visited.add(source)
            for uri in re.findall(r'''^\s*(?:import|export|part)\s+['"]([^'"]+)''', source.read_text(), re.M):
                if ':' not in uri:
                    pending.append(source.parent / uri)
        self.assertIn((self.target / 'lib/seasonal/seasonal_scene_support.dart').resolve(), visited)

    def test_missing_shared_support_aborts_before_any_changes(self):
        (self.source / 'lib/seasonal/seasonal_scene_support.dart').unlink()
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.unchanged()
        self.assertFalse(self.backup.exists())

    def test_existing_matching_shared_support_is_not_replaced(self):
        name = 'lib/seasonal/seasonal_scene_support.dart'
        self.write(self.target / name, (self.source / name).read_text())
        os.utime(self.target / name, (1000000000, 1000000000))
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.target / name).stat().st_mtime, 1000000000)
        self.assertNotIn(name, (self.backup / 'new-files.txt').read_text().splitlines())
        self.assertFalse((self.backup / name).exists())

    def test_different_existing_shared_support_aborts_without_overwriting(self):
        name = 'lib/seasonal/seasonal_scene_support.dart'
        self.write(self.target / name, 'locally changed shared helper')
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.target / name).read_text(), 'locally changed shared helper')
        self.unchanged()
        self.assertFalse(self.backup.exists())

    def test_stale_flutter_path_cannot_silently_build_the_wrong_project(self):
        self.write(self.target / 'ios/Flutter/Generated.xcconfig', 'FLUTTER_APPLICATION_PATH=/another/project\n')
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('/another/project', result.stdout)
        self.unchanged()
        self.assertFalse(self.backup.exists())

    def test_failed_backup_aborts_before_any_replacement(self):
        self.stub('ditto', '#!/bin/sh\nexit 1\n')
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.unchanged()
        self.assertFalse((self.target / FILES[1]).exists())


if __name__ == '__main__':
    unittest.main()
