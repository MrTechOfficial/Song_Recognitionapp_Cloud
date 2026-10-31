#!/bin/bash
# Install the Halloween/Christmas, event, widget and decoration-energy update.
set -euo pipefail
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Run this installer in Terminal on your Mac."
  exit 1
fi
reczt_source="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
reczt_project="${1:-$HOME/Documents/Reczt - Xcode}"
reczt_files=(
  "lib/seasonal/halloween_scene_v2.dart"
  "lib/seasonal/halloween_motion.dart"
  "lib/seasonal/halloween_characters.dart"
  "lib/seasonal/halloween_carvings.dart"
  "lib/main.dart"
  "lib/seasonal/halloween_timeline.dart"
  "lib/seasonal/halloween_bats.dart"
  "lib/seasonal/halloween_event.dart"
  "lib/seasonal/scene_frame_clock.dart"
  "lib/seasonal/christmas_scene.dart"
  "lib/seasonal/christmas_skating.dart"
  "lib/seasonal/christmas_weather.dart"
  "assets/seasonal/halloween_v2/background_living_sky.png"
  "assets/seasonal/halloween_v2/sky_cloud_0.png"
  "assets/seasonal/halloween_v2/sky_cloud_1.png"
  "assets/seasonal/halloween_v2/sky_cloud_2.png"
  "assets/seasonal/halloween_v2/sky_cloud_3.png"
  "assets/seasonal/halloween_v2/sky_cloud_4.png"
  "assets/seasonal/halloween_v2/sky_cloud_5.png"
  "assets/seasonal/halloween_v2/pumpkin_classic_eyes_mask.png"
  "assets/seasonal/halloween_v2/pumpkin_surprised_eyes_mask.png"
  "assets/seasonal/halloween_v2/pumpkin_sly_eyes_mask.png"
  "assets/seasonal/christmas/christmas_background_edge_fill.png"
  "assets/seasonal/christmas/snowman_body_rig.png"
  "assets/seasonal/christmas/snowman_skate_back.png"
  "assets/seasonal/christmas/snowman_skate_front.png"
  "assets/seasonal/christmas/snowman_scarf_tail.png"
  "ios/Runner/AppDelegate.swift"
  "ios/RecztControl/RecztControlControl.swift"
  "ios/RecztControl/RecztIdentifySongControl.swift"
  "ios/RecztControl/RecztQuickIdentifyWidget.swift"
  "ios/RecztControl/RecztRecognitionLiveActivity.swift"
  "test/christmas_rig_render_test.dart"
  "test/widget_test.dart"
  "test/scene_energy_test.dart"
  "test/halloween_event_test.dart"
  "assets/seasonal/halloween_v2/background_tree_clear.png"
  "assets/seasonal/halloween_v2/tree_isolated.png"
  "assets/seasonal/halloween_v2/moon_cloud_clean.png"
  "assets/seasonal/halloween_v2/pumpkin_closed.png"
  "assets/seasonal/halloween_v2/pumpkin_classic_light_mask.png"
  "assets/seasonal/halloween_v2/pumpkin_surprised_light_mask.png"
  "assets/seasonal/halloween_v2/pumpkin_closed_light_mask.png"
  "assets/seasonal/halloween_v2/skeleton_eyes_closed_overlay.png"
  "assets/seasonal/halloween_v2/skeleton_skull_rig.png"
  "assets/seasonal/halloween_v2/pumpkin_shell.png"
  "assets/seasonal/halloween_v2/fog_far_clean.png"
  "assets/seasonal/halloween_v2/fog_near_clean.png"
  "assets/seasonal/halloween_v2/moon_cloud_bank.png"
  "test/seasonal_scenes_test.dart"
  "test/halloween_motion_test.dart"
  "test/halloween_scene_test.dart"
  "test/halloween_assets_test.dart"
  "test/halloween_rig_render_test.dart"
)
if [ ! -f "$reczt_project/pubspec.yaml" ] ||
   [ ! -d "$reczt_project/ios/Runner.xcworkspace" ] ||
   [ ! -f "$reczt_project/lib/seasonal/halloween_scene_v2.dart" ]; then
  echo "Working project not found at: $reczt_project"
  echo "Pass your working project folder as the installer's first argument."
  exit 1
fi
reczt_project="$(cd "$reczt_project" && pwd)"
if [ "$reczt_source" = "$reczt_project" ]; then
  echo "Run the installer from the newly extracted ZIP, separate from the working project."
  exit 1
fi
if ! grep -Fq 'assets/seasonal/halloween_v2/' "$reczt_project/pubspec.yaml"; then
  echo "This working project's Halloween asset declaration is missing. No files have been changed."
  exit 1
fi
if ! grep -Fq 'assets/seasonal/christmas/' "$reczt_project/pubspec.yaml"; then
  echo "The Christmas asset declaration is missing. No files have been changed."
  exit 1
fi
# Require the existing app/scene entry points. Earlier seasonal installs can lack
# the weather/skating helpers; both are supplied by this download and can be
# added below, with missing paths recorded in the backup's new-files manifest.
for reczt_existing in \
  "lib/main.dart" \
  "lib/seasonal/christmas_scene.dart"; do
  if [ ! -f "$reczt_project/$reczt_existing" ]; then
    echo "Existing project dependency missing: $reczt_existing"
    echo "Use the working project from the previous update. No files have been changed."
    exit 1
  fi
done
# Avoid the stale-path problem seen earlier in this session: the workspace must
# actually build the directory receiving the new Dart code and assets.
reczt_config="$reczt_project/ios/Flutter/Generated.xcconfig"
if [ ! -f "$reczt_config" ]; then
  echo "Flutter configuration is missing in this working project. No files have been changed."
  exit 1
fi
reczt_configured="$(sed -n 's/^FLUTTER_APPLICATION_PATH=//p' "$reczt_config" | tr -d '\r')"
if [ ! -d "$reczt_configured" ] ||
   [ "$(cd "$reczt_configured" && pwd -P)" != "$(cd "$reczt_project" && pwd -P)" ]; then
  echo "This workspace is configured to build: $reczt_configured"
  echo "Requested update folder: $reczt_project"
  echo "Use the actual working project path as the first argument. No files have been changed."
  exit 1
fi
# Earlier installers omitted this imported base class/canvas. Add it when
# missing, without replacing an existing helper used by the Christmas scene.
reczt_support="lib/seasonal/seasonal_scene_support.dart"
if [ ! -f "$reczt_source/$reczt_support" ]; then
  echo "Downloaded file missing: $reczt_support. No files have been changed."
  exit 1
fi
if [ -e "$reczt_project/$reczt_support" ] || [ -L "$reczt_project/$reczt_support" ]; then
  if ! cmp -s "$reczt_source/$reczt_support" "$reczt_project/$reczt_support"; then
    echo "The existing shared scene helper differs from this update: $reczt_support"
    echo "Keep that file for review before installing. No files have been changed."
    exit 1
  fi
else
  reczt_files+=("$reczt_support")
fi
for reczt_file in "${reczt_files[@]}"; do
  case "$reczt_file" in
    ios/*)
      if [ ! -f "$reczt_project/$reczt_file" ]; then
        echo "Existing native file missing: $reczt_file. No files have been changed."
        exit 1
      fi
      ;;
  esac
  if [ ! -f "$reczt_source/$reczt_file" ]; then
    echo "Downloaded file missing: $reczt_file. No files have been changed."
    exit 1
  fi
done
reczt_backup="$(mktemp -d "$HOME/Desktop/Reczt-Seasonal-backup-XXXXXX")"
: > "$reczt_backup/new-files.txt"
for reczt_file in "${reczt_files[@]}"; do
  if [ -f "$reczt_project/$reczt_file" ]; then
    mkdir -p "$(dirname "$reczt_backup/$reczt_file")"
    ditto "$reczt_project/$reczt_file" "$reczt_backup/$reczt_file"
  else
    echo "$reczt_file" >> "$reczt_backup/new-files.txt"
  fi
done
# Finish every backup before replacing anything, including the revised native
# icon/energy bridge files and Christmas rig. Pods, signing, entitlements,
# generated Flutter configuration and the Xcode project are never copied.
for reczt_file in "${reczt_files[@]}"; do
  mkdir -p "$(dirname "$reczt_project/$reczt_file")"
  ditto "$reczt_source/$reczt_file" "$reczt_project/$reczt_file"
done
echo "Seasonal animation, event and widget update installed in: $reczt_project"
echo "Your backup is at: $reczt_backup"
echo "In Xcode, stop the app and Run Runner, then select Halloween in App Preferences."
open "$reczt_project/ios/Runner.xcworkspace"
