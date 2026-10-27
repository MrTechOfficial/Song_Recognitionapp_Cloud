#!/bin/bash
# Standalone repair for the dependency omitted by the first Halloween installer.
# It only adds the missing helper; no Flutter/Pods reset or ZIP is required.
set -euo pipefail
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Run this repair in Terminal on your Mac."
  exit 1
fi
reczt_project="${1:-$HOME/Documents/Reczt - Xcode}"
if [ ! -f "$reczt_project/pubspec.yaml" ] ||
   [ ! -d "$reczt_project/ios/Runner.xcworkspace" ] ||
   [ ! -f "$reczt_project/lib/seasonal/halloween_scene_v2.dart" ]; then
  echo "Working project not found at: $reczt_project"
  echo "Pass your working project folder as the repair's first argument."
  exit 1
fi
reczt_config="$reczt_project/ios/Flutter/Generated.xcconfig"
if [ ! -f "$reczt_config" ]; then
  echo "Flutter configuration is missing. No files have been changed."
  exit 1
fi
reczt_configured="$(sed -n 's/^FLUTTER_APPLICATION_PATH=//p' "$reczt_config" | tr -d '\r')"
if [ ! -d "$reczt_configured" ] ||
   [ "$(cd "$reczt_configured" && pwd -P)" != "$(cd "$reczt_project" && pwd -P)" ]; then
  echo "This workspace is configured to build: $reczt_configured"
  echo "Requested repair folder: $reczt_project. No files have been changed."
  exit 1
fi
reczt_support="$reczt_project/lib/seasonal/seasonal_scene_support.dart"
reczt_expected="7aaf1d8d5b460e92b73f91af4e087026925110b6621dcb92453b5f11adff9e61"
if [ -e "$reczt_support" ] || [ -L "$reczt_support" ]; then
  if [ -f "$reczt_support" ] &&
     [ "$(shasum -a 256 "$reczt_support" | awk '{print $1}')" = "$reczt_expected" ]; then
    echo "The expected shared helper is already present. No files were changed."
    open "$reczt_project/ios/Runner.xcworkspace"
    exit 0
  fi
  echo "An existing shared helper differs from the expected file: $reczt_support"
  echo "It was preserved. Share the first error in the build log for review."
  exit 1
fi
reczt_temp="$(mktemp -d "${TMPDIR:-/tmp}/reczt-halloween-support.XXXXXX")"
trap 'rm -rf "$reczt_temp"' EXIT
curl --fail --location --retry 2 --connect-timeout 10 --max-time 60 \
  'https://raw.githubusercontent.com/MrTechOfficial/Song_Recognitionapp_Cloud/9bc4545bd04de0daaf0b382512c80fc567529274/lib/seasonal/seasonal_scene_support.dart' \
  --output "$reczt_temp/seasonal_scene_support.dart"
if [ "$(shasum -a 256 "$reczt_temp/seasonal_scene_support.dart" | awk '{print $1}')" != "$reczt_expected" ]; then
  echo "The downloaded helper failed verification. No files have been changed."
  exit 1
fi
# Never overwrite an existing helper, including one created during the download.
cp -n "$reczt_temp/seasonal_scene_support.dart" "$reczt_support"
if [ "$(shasum -a 256 "$reczt_support" | awk '{print $1}')" != "$reczt_expected" ]; then
  echo "The helper could not be installed safely. Existing files were preserved."
  exit 1
fi
echo "Added the missing shared scene helper in: $reczt_project"
echo "In Xcode, stop the app and Run Runner again."
open "$reczt_project/ios/Runner.xcworkspace"
