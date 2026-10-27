"""The standalone repair adds one verified dependency and preserves the project."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/repair-halloween-support-macos.sh'
SUPPORT = ROOT / 'lib/seasonal/seasonal_scene_support.dart'


class HalloweenSupportRepairTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='reczt-support-')
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.project = self.base / 'working project with spaces'
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.support = self.project / 'lib/seasonal/seasonal_scene_support.dart'
        self.write(self.project / 'pubspec.yaml', 'preserve pubspec')
        self.write(self.project / 'lib/seasonal/halloween_scene_v2.dart', 'preserve Halloween')
        self.write(self.project / 'lib/seasonal/christmas_scene.dart', 'preserve Christmas')
        self.write(self.project / 'ios/Runner.xcodeproj/project.pbxproj', 'preserve Xcode')
        self.config = self.project / 'ios/Flutter/Generated.xcconfig'
        self.write(self.config, f'FLUTTER_APPLICATION_PATH={self.project}\n')
        (self.project / 'ios/Runner.xcworkspace').mkdir()
        self.original = {p: p.read_bytes() for p in self.project.rglob('*') if p.is_file()}
        self.download = self.base / 'download.dart'
        self.download.write_bytes(SUPPORT.read_bytes())
        self.stub('uname', '#!/bin/sh\necho Darwin\n')
        self.stub('curl', '''#!/usr/bin/env python3
import os,pathlib,sys
pathlib.Path(os.environ['RECZT_TEST_CALLED']).touch()
pathlib.Path(sys.argv[sys.argv.index('--output')+1]).write_bytes(pathlib.Path(os.environ['RECZT_TEST_DOWNLOAD']).read_bytes())
''')
        self.stub('open', '''#!/usr/bin/env python3
import os,pathlib,sys
pathlib.Path(os.environ['RECZT_TEST_OPEN']).write_text(sys.argv[1])
''')
        self.opened = self.base / 'opened'
        self.called = self.base / 'download-called'
        self.env = dict(os.environ, RECZT_TEST_DOWNLOAD=str(self.download),
                        RECZT_TEST_CALLED=str(self.called), RECZT_TEST_OPEN=str(self.opened))
        self.env['PATH'] = str(self.bin) + os.pathsep + os.environ['PATH']

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def stub(self, name, text):
        file = self.bin / name
        file.write_text(text)
        file.chmod(0o755)

    def repair(self):
        result = subprocess.run(['bash', str(SCRIPT), str(self.project)],
                                env=self.env, capture_output=True, text=True)
        for path, contents in self.original.items():
            self.assertEqual(path.read_bytes(), contents)
        return result

    def test_missing_helper_is_added_with_verified_original_contents(self):
        result = self.repair()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.support.read_bytes(), SUPPORT.read_bytes())
        self.assertEqual(self.opened.read_text(), str(self.project / 'ios/Runner.xcworkspace'))
        files = {p for p in self.project.rglob('*') if p.is_file()}
        self.assertEqual(files, set(self.original) | {self.support})

    def test_failed_download_does_not_leave_a_partial_helper(self):
        self.stub('curl', '#!/bin/sh\nexit 22\n')
        self.assertNotEqual(self.repair().returncode, 0)
        self.assertFalse(self.support.exists())
        self.assertFalse(self.opened.exists())

    def test_wrong_download_checksum_aborts_without_installing(self):
        self.download.write_text('not the expected Dart file')
        result = self.repair()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('failed verification', result.stdout)
        self.assertFalse(self.support.exists())
        self.assertFalse(self.opened.exists())

    def test_existing_expected_helper_is_reused_without_downloading(self):
        self.support.write_bytes(SUPPORT.read_bytes())
        os.utime(self.support, (1000000000, 1000000000))
        result = self.repair()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.support.stat().st_mtime, 1000000000)
        self.assertFalse(self.called.exists())

    def test_locally_changed_helper_is_preserved_without_downloading(self):
        self.support.write_text('locally changed helper')
        result = self.repair()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.support.read_text(), 'locally changed helper')
        self.assertFalse(self.called.exists())
        self.assertFalse(self.opened.exists())

    def test_stale_build_path_aborts_before_download(self):
        self.write(self.config, 'FLUTTER_APPLICATION_PATH=/wrong/project\n')
        self.original[self.config] = self.config.read_bytes()
        self.assertNotEqual(self.repair().returncode, 0)
        self.assertFalse(self.called.exists())
        self.assertFalse(self.support.exists())
        self.assertFalse(self.opened.exists())


if __name__ == '__main__':
    unittest.main()
