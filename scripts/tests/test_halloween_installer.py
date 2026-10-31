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
    'lib/seasonal/halloween_characters.dart', 'lib/seasonal/halloween_carvings.dart',
    'lib/main.dart',
    'lib/seasonal/halloween_timeline.dart',
    'lib/seasonal/halloween_bats.dart',
    'lib/seasonal/halloween_event.dart',
    'lib/seasonal/scene_frame_clock.dart',
    'lib/seasonal/christmas_scene.dart',
    'lib/seasonal/christmas_skating.dart',
    'lib/seasonal/christmas_weather.dart',
    'assets/seasonal/halloween_v2/background_living_sky.png',
    'assets/seasonal/halloween_v2/sky_cloud_0.png',
    'assets/seasonal/halloween_v2/sky_cloud_1.png',
    'assets/seasonal/halloween_v2/sky_cloud_2.png',
    'assets/seasonal/halloween_v2/sky_cloud_3.png',
    'assets/seasonal/halloween_v2/sky_cloud_4.png',
    'assets/seasonal/halloween_v2/sky_cloud_5.png',
    'assets/seasonal/halloween_v2/pumpkin_classic_eyes_mask.png',
    'assets/seasonal/halloween_v2/pumpkin_surprised_eyes_mask.png',
    'assets/seasonal/halloween_v2/pumpkin_sly_eyes_mask.png',
    'assets/seasonal/christmas/christmas_background_edge_fill.png',
    'assets/seasonal/christmas/snowman_body_rig.png',
    'assets/seasonal/christmas/snowman_skate_back.png',
    'assets/seasonal/christmas/snowman_skate_front.png',
    'assets/seasonal/christmas/snowman_scarf_tail.png',
    'ios/Runner/AppDelegate.swift',
    'ios/RecztControl/RecztControlControl.swift',
    'ios/RecztControl/RecztIdentifySongControl.swift',
    'ios/RecztControl/RecztQuickIdentifyWidget.swift',
    'ios/RecztControl/RecztRecognitionLiveActivity.swift',
    'test/christmas_rig_render_test.dart',
    'test/widget_test.dart',
    'test/scene_energy_test.dart',
    'test/halloween_event_test.dart',
    'lib/seasonal/seasonal_scene_support.dart',
    *['assets/seasonal/halloween_v2/' + name + '.png' for name in [
        'background_tree_clear', 'tree_isolated', 'moon_cloud_clean', 'pumpkin_closed',
        'pumpkin_classic_light_mask', 'pumpkin_surprised_light_mask',
        'pumpkin_closed_light_mask', 'skeleton_eyes_closed_overlay',
        'skeleton_skull_rig', 'pumpkin_shell', 'fog_far_clean', 'fog_near_clean',
        'moon_cloud_bank']],
    'test/seasonal_scenes_test.dart', 'test/halloween_motion_test.dart',
    'test/halloween_scene_test.dart', 'test/halloween_assets_test.dart',
    'test/halloween_rig_render_test.dart',
]
EXISTING = {FILES[0], 'lib/main.dart', 'test/seasonal_scenes_test.dart', 'test/widget_test.dart',
    *[name for name in FILES if name.startswith('ios/') or name.startswith('lib/seasonal/christmas_')]}


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
        self.write(self.target / 'pubspec.yaml', 'flutter:\n  assets:\n    - assets/seasonal/halloween_v2/\n    - assets/seasonal/christmas/\n')
        (self.target / 'ios/Runner.xcworkspace').mkdir(parents=True)
        self.write(self.target / 'ios/Flutter/Generated.xcconfig', f'FLUTTER_APPLICATION_PATH={self.target}\n')
        self.protected = ['assets/seasonal/christmas/christmas_background_clean.png',
            'ios/Runner/iOS 27 System Integration/RecztRecognitionCoordinator.swift',
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

    def test_missing_new_snowman_layer_aborts_before_any_writes(self):
        (self.source / 'assets/seasonal/christmas/snowman_scarf_tail.png').unlink()
        self.assertNotEqual(self.install().returncode, 0)
        self.unchanged()
        self.assertFalse(self.backup.exists())

    def test_missing_existing_native_file_aborts_before_any_writes(self):
        missing = 'ios/Runner/AppDelegate.swift'
        (self.target / missing).unlink()
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(missing, result.stdout)
        self.assertEqual((self.target / 'lib/main.dart').read_text(), 'old: lib/main.dart')
        self.assertFalse(self.backup.exists())

    def test_installed_scene_contains_every_relative_dart_dependency(self):
        # Use the real libraries, rather than synthetic manifest contents, so
        # this catches a helper omitted from both the script and FILES above.
        for source in (ROOT / 'lib/seasonal').glob('*.dart'):
            self.write(self.source / 'lib/seasonal' / source.name, source.read_text())
        self.write(self.source / 'lib/main.dart', (ROOT / 'lib/main.dart').read_text())
        # An older working project can be missing both extracted Christmas
        # helpers. Resolve the real main.dart import graph after installing.
        missing_helpers = {'christmas_weather.dart', 'christmas_skating.dart'}
        for name in missing_helpers:
            (self.target / 'lib/seasonal' / name).unlink()
        for source in (ROOT / 'lib/seasonal').glob('*.dart'):
            if source.name not in {'halloween_timeline.dart', 'halloween_bats.dart',
                    'halloween_event.dart', 'scene_frame_clock.dart'} | missing_helpers:
                self.write(self.target / 'lib/seasonal' / source.name, source.read_text())
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        pending = [self.target / 'lib/main.dart']
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
        added = set((self.backup / 'new-files.txt').read_text().splitlines())
        for name in missing_helpers:
            self.assertIn((self.target / 'lib/seasonal' / name).resolve(), visited)
            self.assertIn('lib/seasonal/' + name, added)

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

    def test_missing_christmas_weather_is_installed_and_recorded_as_new(self):
        missing = 'lib/seasonal/christmas_weather.dart'
        (self.target / missing).unlink()
        config = (self.target / 'ios/Flutter/Generated.xcconfig').read_bytes()
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in FILES:
            self.assertEqual((self.target / name).read_text(), 'new: ' + name)
        for name in EXISTING - {missing}:
            self.assertEqual((self.backup / name).read_text(), 'old: ' + name)
        self.assertFalse((self.backup / missing).exists())
        self.assertEqual(set((self.backup / 'new-files.txt').read_text().splitlines()),
                         (set(FILES) - EXISTING) | {missing})
        for name in self.protected:
            self.assertEqual((self.target / name).read_text(), 'preserve: ' + name)
        self.assertEqual((self.target / 'ios/Flutter/Generated.xcconfig').read_bytes(), config)
        self.assertEqual((self.base / 'opened').read_text(), str(self.target / 'ios/Runner.xcworkspace'))


if __name__ == '__main__':
    unittest.main()
