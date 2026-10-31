"""Export native Live Activity copy from Reczt's canonical Flutter dictionaries.

Run with --check to detect stale/missing translations without writing files.
Embedding in the existing widget source avoids modifying a user's Xcode project
or relying on an unregistered localization resource during a ZIP installation.
"""
import argparse
import ast
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WIDGET = ROOT / 'ios/RecztControl/RecztRecognitionLiveActivity.swift'
BEGIN = '    // BEGIN GENERATED ACTIVITY DICTIONARIES'
END = '    // END GENERATED ACTIVITY DICTIONARIES'
KEYS = ['listening', 'searching', 'match_found', 'mic_denied',
        'activity_no_match', 'activity_ended', 'activity_error',
        'activity_listening_hint', 'activity_search_hint', 'activity_seconds_remaining']


def generated():
    source = (ROOT / 'lib/main.dart').read_text()
    start = source.index('final Map<String, Map<String, String>> localizedStrings = {')
    source = source[start:source.index('\n};', start)]
    dictionaries = {}
    for language, block in re.findall(r"^  '([^']+)': \{\n(.*?)^  \},", source, re.M | re.S):
        values = {}
        for key in KEYS:
            match = re.search(r'''^\s*['"]''' + re.escape(key) +
                              r'''['"]\s*:\s*((?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'))\s*,''', block, re.M)
            if not match:
                raise ValueError(f'Missing {language}/{key}')
            values[key] = ast.literal_eval(match[1])
        dictionaries[language] = values
    if len(dictionaries) != 15:
        raise ValueError(f'Expected all 15 dictionaries, got {len(dictionaries)}')
    lines = [BEGIN, '    static let dictionaries: [String: [String: String]] = [']
    for language, values in dictionaries.items():
        lines.append(f'        "{language}": [')
        for key, value in values.items():
            lines.append(f'            "{key}": {json.dumps(value, ensure_ascii=False)},')
        lines.append('        ],')
    lines += ['    ]', END]
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    text = WIDGET.read_text()
    start, end = text.index(BEGIN), text.index(END) + len(END)
    expected = generated()
    if args.check:
        if text[start:end] != expected:
            raise SystemExit('Native activity translations are stale. Run this script without --check.')
        print('All 15 native activity dictionaries match the Flutter source.')
    else:
        WIDGET.write_text(text[:start] + expected + text[end:])
        print('Exported 15 native activity dictionaries from lib/main.dart.')


if __name__ == '__main__':
    main()
