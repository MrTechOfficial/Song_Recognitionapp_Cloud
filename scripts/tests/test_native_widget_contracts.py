"""Check the native delivery boundaries behind the Control Center/painted UI fixes."""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / 'ios/RecztControl'

class NativeWidgetContracts(unittest.TestCase):
    def test_only_one_control_is_published_and_it_opens_the_app(self):
        types = set()
        for path in NATIVE.glob('*.swift'):
            types.update(re.findall(r'struct (\w+): ControlWidget\b', path.read_text()))
        registered = set(re.findall(r'\b(Reczt\w+)\(\)', (NATIVE/'RecztControlBundle.swift').read_text()))
        self.assertEqual(types & registered, {'RecztControlControl'})
        intent = (NATIVE/'RecztOpenIntent.swift').read_text()
        self.assertIn('openAppWhenRun: Bool { true }', intent)
        self.assertIn('reczt.control.startRecording', intent)
        self.assertIn('reczt.control.startRecording', (ROOT/'ios/Runner/AppDelegate.swift').read_text())

    def test_painted_images_are_supplied_to_the_installer(self):
        widget = (NATIVE/'RecztRecognitionLiveActivity.swift').read_text()
        installer = (ROOT/'scripts/install-halloween-update-macos.sh').read_text()
        names = re.findall(r'Image\("(Reczt\w+)"\)', widget)
        self.assertGreaterEqual(len(names), 5)
        for name in names:
            folder = NATIVE/'Assets.xcassets'/f'{name}.imageset'
            metadata = json.loads((folder/'Contents.json').read_text())
            for image in metadata['images']:
                data = folder/image['filename']
                self.assertTrue(data.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'))
                self.assertIn(str(data.relative_to(ROOT)), installer)
            self.assertIn(str((folder/'Contents.json').relative_to(ROOT)), installer)

if __name__ == '__main__':
    unittest.main()
