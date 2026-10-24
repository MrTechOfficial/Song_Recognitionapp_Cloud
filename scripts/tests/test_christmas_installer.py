"""Check update/backup behavior on Linux with the Mac utilities substituted."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
INSTALLER = ROOT / "scripts/install-christmas-update-macos.sh"
# Check the expected delivered native files independently of the installer's
# list, including paths with spaces and the native migration tests.
NATIVE_FILES = [
    "ios/RecztControl/RecztRecognitionLiveActivity.swift",
    "ios/Runner/iOS 27 System Integration/RecztRecognitionAttributes.swift",
    "ios/Runner/iOS 27 System Integration/RecztLiveActivityManager.swift",
    "ios/Runner/iOS 27 System Integration/RecztSharedStore.swift",
    "ios/Runner/iOS 27 System Integration/RecztIOS27Bridge.swift",
    "ios/RunnerTests/RunnerTests.swift",
]


class ChristmasInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="reczt-install-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source, self.target = self.base / "new source", self.base / "working project"
        self.backup, self.bin = self.base / "backup", self.base / "bin"
        self.bin.mkdir()
        for root, marker in [(self.source, "new"), (self.target, "old")]:
            for name in ["lib/main.dart", "lib/seasonal/christmas_weather.dart", *NATIVE_FILES]:
                file = root / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text(f"{marker}: {name}")
        (self.target / "pubspec.yaml").write_text("working dependencies")
        (self.target / "ios/Runner.xcworkspace").mkdir()
        self.protected = ["ios/Pods/keep", "ios/Flutter/Generated.xcconfig", "ios/Runner.xcodeproj/project.pbxproj", "ios/Runner/Runner.entitlements"]
        for name in self.protected:
            file = self.target / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("preserve working configuration")
        (self.source / "scripts").mkdir()
        shutil.copy2(INSTALLER, self.source / "scripts" / INSTALLER.name)
        self.stub("uname", "#!/bin/sh\necho Darwin\n")
        self.stub("mktemp", "#!/usr/bin/env python3\nimport os,pathlib\np=pathlib.Path(os.environ['RECZT_TEST_BACKUP']);p.mkdir();print(p)\n")
        self.stub("ditto", "#!/usr/bin/env python3\nimport pathlib,shutil,sys\na,b=map(pathlib.Path,sys.argv[1:]);b.parent.mkdir(parents=True,exist_ok=True)\nif a.is_dir(): shutil.copytree(a,b,dirs_exist_ok=True)\nelse: shutil.copy2(a,b)\n")
        self.stub("open", "#!/usr/bin/env python3\nimport os,pathlib,sys\npathlib.Path(os.environ['RECZT_TEST_OPEN']).write_text(sys.argv[1])\n")
        self.env = dict(os.environ, RECZT_TEST_BACKUP=str(self.backup), RECZT_TEST_OPEN=str(self.base / "opened"))
        self.env["PATH"] = str(self.bin) + os.pathsep + os.environ["PATH"]

    def stub(self, name, contents):
        file = self.bin / name
        file.write_text(contents)
        file.chmod(0o755)

    def run_installer(self):
        return subprocess.run(["bash", str(self.source / "scripts" / INSTALLER.name), str(self.target)], env=self.env, capture_output=True, text=True)

    def test_updates_native_and_dart_and_preserves_working_configuration(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in ["lib/main.dart", "lib/seasonal/christmas_weather.dart", *NATIVE_FILES]:
            self.assertEqual((self.target / name).read_text(), f"new: {name}")
            self.assertEqual((self.backup / name).read_text(), f"old: {name}")
        for name in self.protected:
            self.assertEqual((self.target / name).read_text(), "preserve working configuration")
        self.assertEqual((self.base / "opened").read_text(), str(self.target / "ios/Runner.xcworkspace"))

    def test_missing_native_file_aborts_before_any_changes(self):
        (self.target / NATIVE_FILES[-2]).unlink()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No files have been changed", result.stdout)
        self.assertEqual((self.target / "lib/main.dart").read_text(), "old: lib/main.dart")
        self.assertFalse(self.backup.exists())
        self.assertFalse((self.base / "opened").exists())

    def test_failed_backup_aborts_before_replacing_code(self):
        self.stub("ditto", "#!/bin/sh\nexit 1\n")
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.target / "lib/main.dart").read_text(), "old: lib/main.dart")
        for name in NATIVE_FILES:
            self.assertEqual((self.target / name).read_text(), f"old: {name}")
        self.assertFalse((self.base / "opened").exists())


if __name__ == "__main__":
    unittest.main()
