#!/bin/bash
# Run from the newly extracted project ZIP. The optional argument selects a
# different working project; the default is the folder used in this session.
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Run this installer in Terminal on your Mac."
  exit 1
fi

reczt_source="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
reczt_project="${1:-$HOME/Downloads/Song_Recognitionapp_Cloud-seasonal-ui-update}"
reczt_native_files=(
  "ios/RecztControl/RecztRecognitionLiveActivity.swift"
  "ios/Runner/iOS 27 System Integration/RecztRecognitionAttributes.swift"
  "ios/Runner/iOS 27 System Integration/RecztLiveActivityManager.swift"
  "ios/Runner/iOS 27 System Integration/RecztSharedStore.swift"
  "ios/Runner/iOS 27 System Integration/RecztIOS27Bridge.swift"
  "ios/RunnerTests/RunnerTests.swift"
)

if [ ! -f "$reczt_source/lib/seasonal/christmas_weather.dart" ] ||
   [ ! -f "$reczt_project/pubspec.yaml" ] ||
   [ ! -d "$reczt_project/ios/Runner.xcworkspace" ]; then
  echo "New code or working project not found. Working project: $reczt_project"
  exit 1
fi
if [ "$reczt_source" = "$(cd "$reczt_project" && pwd)" ]; then
  echo "Run this from the newly extracted ZIP, separate from the working project."
  exit 1
fi

# Check every native file before backing up or changing the working app.
for reczt_file in "${reczt_native_files[@]}"; do
  if [ ! -f "$reczt_source/$reczt_file" ] || [ ! -f "$reczt_project/$reczt_file" ]; then
    echo "Required file missing: $reczt_file. No files have been changed."
    exit 1
  fi
done

reczt_backup="$(mktemp -d "$HOME/Desktop/Reczt-update-backup-XXXXXX")"
ditto "$reczt_project/lib" "$reczt_backup/lib"
for reczt_file in "${reczt_native_files[@]}"; do
  mkdir -p "$(dirname "$reczt_backup/$reczt_file")"
  ditto "$reczt_project/$reczt_file" "$reczt_backup/$reczt_file"
done

# All backups finish before any code is replaced. Pods, generated Flutter
# configuration, signing, entitlements and the Xcode project stay in place.
ditto "$reczt_source/lib" "$reczt_project/lib"
for reczt_file in "${reczt_native_files[@]}"; do
  ditto "$reczt_source/$reczt_file" "$reczt_project/$reczt_file"
done

echo "Christmas scene and Dynamic Island update installed."
echo "Your backup is at: $reczt_backup"
open "$reczt_project/ios/Runner.xcworkspace"
