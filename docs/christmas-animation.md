# Christmas lake animation

Christmas keeps the blue frozen lake, moon/cabin composition, icy-white headings,
dark translucent cards and instruction backing. Halloween, shared scene lifecycle,
app assets, dependencies and iOS files are unchanged by this update.

## Current behavior

- The snowman is about 60% larger than the last delivered version: 104–228
  artwork units instead of 64–144, with perspective scaling preserved. The
  opening phase now shows a near-shore pass instead of beginning behind the
  environment cards. Shoreline margins accommodate the larger character.
- A continuous 96-second route visits the distant shoreline and the left/right
  portions of the lake. Near passes use more of the sides, where the compact
  interface leaves room to notice him.
- The route is anchored exclusively to the illustration and viewport crop.
  Scrolling, button positions, instruction text, and foreground layout NEVER
  move, resize, or retarget the snowman. UI measurement and route retargeting
  code have been removed. Only viewport rotation/cropping affects the lake bounds.
- The Christmas environment cards have 8-point gaps instead of 12-point gaps.
  The oversized 96-point gap before the instructions is now 20 points. Card
  touch areas, typography and contrast treatments remain intact.
- The two existing skate poses blend below a stable upper body. Distance affects
  cadence, lean, push lift, shadow and reflection. Pushes ease into longer glides.
- Individual string lights visibly dim and brighten on staggered eight-second
  cycles. Larger colored halos, warm-white bulb cores and brief sparkles make
  their contrast visible at phone size. Several can twinkle independently; the
  whole string never flashes together. Centers and tilts match the drawn bulbs.
- A larger, shaded slab of snow slides off the front gable's snowy edge, falls
  under gravity, then breaks into a powder puff on the bank. It begins at three
  seconds of scene time and repeats every 24 seconds. The visible slide happens
  above the cards; the lower landing naturally passes behind the interface.
- Three layered, sketched cloud shapes travel visibly through the sky, wrapping
  outside the artwork. Their different speeds preserve depth.
- More visible diagonal snowfall responds to a stronger breeze. Short curls of
  wind-blown powder cross the foreground every 12 seconds, starting in the
  opening seconds. A foreground twig sways with the same wind; chimney smoke
  remains gentle.
- Reduced-motion and app lifecycle/ticker controls pause the scene and weather.

## Update the working Mac project

The delivery branch is `seasonal-ui-update`; `main` is untouched. Actions remain
disabled on this branch and upload commits use `[skip ci]`.

1. Download the latest branch ZIP and unzip it into a separate folder.
2. Back up the working project, then replace its **lib folder** with the new
   lib folder. If you made additional local Dart changes, merge the files below
   instead. No assets, dependency updates, Pods reinstall, or iOS project changes
   are needed.
3. Stop the app in Xcode, then Run using the working `ios/Runner.xcworkspace`.
4. Select Christmas. Look at the upper string lights and the cabin's front roof
   edge, then watch the near-lake passes and foreground powder gusts. Observe for
   30 seconds so at least one complete roof event is included. Scrolling the
   controls must not influence the snowman or the weather.

Current implementation files:

- `lib/main.dart` (Christmas spacing and host only)
- `lib/seasonal/christmas_scene.dart`
- `lib/seasonal/christmas_skating.dart`
- `lib/seasonal/christmas_weather.dart` (new)

The obsolete `christmas_scene_layout.dart` measurement module is removed. A
leftover local copy is unused, but replacing lib removes it cleanly.

Close Xcode, then paste this whole block into Mac Terminal to update the working
downloaded project. It downloads the current delivery branch and backs up lib
before copying the new code. It does not change the working iOS/Pods setup.

```bash
(
set -e
reczt_project="$HOME/Downloads/Song_Recognitionapp_Cloud-seasonal-ui-update"
if [ ! -d "$reczt_project/ios/Runner.xcworkspace" ]; then
  echo "Project not found at: $reczt_project"
  exit 1
fi

reczt_temp="$(mktemp -d)"
reczt_backup="$HOME/Desktop/Reczt-lib-backup-$(date +%Y%m%d-%H%M%S)"
curl --fail --location \
  "https://github.com/MrTechOfficial/Song_Recognitionapp_Cloud/archive/refs/heads/seasonal-ui-update.zip" \
  --output "$reczt_temp/update.zip"
ditto -x -k "$reczt_temp/update.zip" "$reczt_temp"
reczt_source="$reczt_temp/Song_Recognitionapp_Cloud-seasonal-ui-update"
test -f "$reczt_source/lib/seasonal/christmas_weather.dart"
ditto "$reczt_project/lib" "$reczt_backup"
ditto "$reczt_source/lib" "$reczt_project/lib"
echo "Update installed. Your backup is at: $reczt_backup"
open "$reczt_project/ios/Runner.xcworkspace"
)
```

In Xcode select Runner and the phone/simulator, then press Run and select
Christmas. No `pod install` or Flutter configuration regeneration is needed for
this code-only update. Older Terminal blocks pinned to an earlier commit still
download that older version; use this block for the current delivery branch.

## Validation

Twelve focused Flutter tests cover route bounds, velocity/stride continuity,
depth, independent visible twinkles, cloud travel and gust timing, roof-snow
physics, foreground hit testing, a synchronized scroll regression, pause/resume,
reduced motion, disposal, small-phone layout, and existing Halloween behavior.
Focused analysis and a production-entrypoint web build are checked. Browser
captures of the full production screen at phone size verify the visible roof
slide/fall, moving clouds and light changes; the recording includes the weather
and near-lake passes. Unrelated existing main.dart warnings are left in place.
Native iPhone performance and the final feel still need an on-device check.

A browser recording of the production screen is available at
[`previews/christmas-motion.mp4`](previews/christmas-motion.mp4). Native fonts,
emoji and frame-rate rendering can differ from this browser capture.
