#!/bin/bash
# Build the existing working app in Flutter Profile mode on a physical device.
set -euo pipefail
reczt_project="${1:-$HOME/Documents/Reczt - Xcode}"
reczt_config="$reczt_project/ios/Flutter/Generated.xcconfig"
if [ ! -f "$reczt_config" ]; then
  echo "Working Flutter configuration missing: $reczt_config"
  exit 1
fi
reczt_sdk="$(sed -n 's/^FLUTTER_ROOT=//p' "$reczt_config" | tr -d '\r')"
if [ ! -x "$reczt_sdk/bin/flutter" ]; then
  echo "Flutter SDK not found at: $reczt_sdk"
  exit 1
fi
cd "$reczt_project"
echo "Running Reczt in Profile mode. Select your physical iPhone if asked."
exec "$reczt_sdk/bin/flutter" run --profile
