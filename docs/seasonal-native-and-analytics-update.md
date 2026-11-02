# Seasonal finishing pass, live countdown and compact analytics

This update follows the small Halloween corrections, clearer skating support,
painted native characters, compact Music Intelligence, and one foreground
Control Center control.

## Halloween

The neck anchor moves two artwork pixels left (338 to 336); head scale changes
from .79 to .75. The middle ground fog is thinner and drifts about 29% faster.
The low distant haze is also lighter; the upper cloud behavior is preserved.

The first pumpkin expression now starts around 18 seconds; normal-face rests
are 16–26 seconds. The existing O face has a shorter visit. The painted landmark
morph remains, so the apertures move smoothly. Rare eye flicker remains rare,
but its maximum dimming increases from about .28 to .64. It affects the eyes,
not the mouth or whole pumpkin. The energy/idle and Reduce Motion policies remain.

## Christmas

The boots sit closer under the body, and weight moves toward the supporting
boot as the other pushes. The route opens on the longer near-shore pass, so both
support feet are visible while travelling in the same direction before a turn.
A regression checks unchanged facing through the opening glide and changing
support. The existing rendered-foot check uses a constant facing as well.

The painted eyes briefly close around seven seconds after scene start, then
occasionally afterward. A small local mesh moves the eye paint; most frames use
the cached torso image. The extra shader shares the owned body image and is
disposed with the scene.

Cabin snow starts on the last section of the left roof slope, rather than sliding
all the way from the peak. The smaller clump keeps some downward momentum as it
leaves the eave, sheds crumbs and settles into the same left-side pile. The first
fall still begins around three seconds after the scene starts.

## Native characters, countdown and Control Center

Both seasonal Live Activities now use the actual painted pumpkin/snowman art,
packed into new image sets in the extension's existing asset catalog. The prior
flat character Canvas is replaced by textured layers. Brief recognition-driven
motion includes gentle rocking and scarf/skate movement. WidgetKit controls
animation delivery; continuous idle 3D loops are not promised. Reduce Motion
keeps still poses.

The timer uses Apple's `Text(timerInterval:countsDown:)` against a stored recording
end date, so its display can count down without a fresh app update for each digit.
Updates preserve that deadline; other phases clear it. Older content lacking a
deadline shows a listening glyph instead of a misleading frozen number. Native
XCTest covers deadline encoding and legacy decoding. Real WidgetKit delivery and
background behavior still need an iPhone check.

Only `RecztControlControl` is registered as a Control Widget. The duplicate
background control is no longer published. The retained control opens Reczt and
queues the normal microphone-recognition start through the existing Siri bridge.
A shared pending flag handles a cold launch and is consumed once; a notification
handles the already-running app. This means **start recording/listening**, rather
than replay a previously saved clip. Home Screen widgets remain separate.

The app requests a one-time controls refresh. iOS owns existing Control Center
placements: if old duplicate tiles remain, remove them and add the single Reczt
control again. App Group identifiers, signing and project files are preserved.

## Compact Music Intelligence and examples

The summary has a fixed 78-point inner height (98 with the existing card padding)
for empty, partial and populated states. The five metrics occupy one row. Long
values use ellipsis with their full value in tooltips/accessibility; text scaling
is bounded for this small tile. Loudness no longer adds a separate row.

Tap the beaker icon on the Music Intelligence card in Analytics to see three
clearly labelled, read-only examples. They do not populate history, counts or
analysis caches. The examples use the sound categories actually handled by the
current native service: vocals, drums and bass. Pace values are illustrative raw
scores, not a claim about the framework's range or units. Real analysis still
depends on the existing device/framework/catalog-preview availability.

All added labels and examples' sound names are in all 15 canonical dictionaries.
The existing native localization export still matches the Flutter dictionaries.

## Testing and lag

Small stutters can come from Debug compilation, the debugger and first-use work.
They should be checked in Profile/Release on the physical phone. Scenery is also
deliberately limited to 24 fps while active, 12 while idle/recording or in Low
Power Mode, with lower thermal budgets. Debug mode alone does not prove that
persistent stutter or idle heat is acceptable.

After installing, close any running Xcode app session. From the extracted ZIP run
`scripts/run-profile-macos.sh` with Bash. It reads the existing Flutter SDK location
from the working project's Generated.xcconfig, then runs `flutter run --profile`.
Choose the physical iPhone if Flutter asks. This avoids relying on Flutter being
on PATH. The optional first argument chooses a working project; the default is
`~/Documents/Reczt - Xcode`.

The Flutter suite passes **49 tests**, including constant-direction support changes,
ice-plane alignment, rendered blinks, all 15 languages at larger text sizes,
fixed card height, and sample-data isolation. All **23 Python installer/native
contract checks** pass. Both production and scene-preview web release builds
pass. Analysis retains the 29 pre-existing main.dart issues; no new issues remain.
Changed Swift files parse successfully, and the native localization export matches.
The browser check opened the actual Analytics samples and both scenes without
page errors. Videos are browser captures of the real Flutter scene renderer;
the winter detail uses the scene preview without foreground controls covering it.

Apple SDKs and Xcode are unavailable in this Linux environment. The native iOS
build, intent delivery, countdown, painted asset rendering and WidgetKit motion
still need device verification. Native XCTest for legacy data and deadline encoding
is included, but has not run here. No native CPU, energy or temperature result is
claimed.

Previews:

- [Compact empty card in Analytics](previews/music-intelligence-compact.png)
- [Read-only sample data](previews/music-intelligence-samples.png)
- [Halloween motion](previews/halloween-motion.mp4)
- [Pumpkin/head detail](previews/halloween-details.mp4)
- [Christmas scene](previews/christmas-motion.mp4)
- [Skating detail](previews/christmas-skating.mp4)
- [Cabin snow detail](previews/christmas-roof-snow.mp4)


## Installation

Extract the **new** source ZIP separately, close Xcode, and run
`scripts/install-halloween-update-macos.sh`. This update needs the new Dart, Swift
and image files together. The installer verifies all source inputs before writes,
backs up existing destinations, records added files and opens the working
Runner.xcworkspace. It adds images only within the already registered extension
asset catalog. Dependencies, generated config, Pods, project files and signing
are not replaced. No GitHub Actions workflow is added.

## File inventory

This revision changes or adds 44 files.

### Flutter

- `lib/main.dart`
- `lib/seasonal/christmas_scene.dart`
- `lib/seasonal/christmas_skating.dart`
- `lib/seasonal/christmas_weather.dart`
- `lib/seasonal/halloween_motion.dart`
- `lib/seasonal/halloween_scene_v2.dart`
- `lib/seasonal/halloween_timeline.dart`
- `lib/seasonal/music_intelligence_card.dart`

### Native implementation and painted assets

- `ios/RecztControl/Assets.xcassets/RecztPumpkinClassic.imageset/Contents.json`
- `ios/RecztControl/Assets.xcassets/RecztPumpkinClassic.imageset/paint.png`
- `ios/RecztControl/Assets.xcassets/RecztSnowmanBody.imageset/Contents.json`
- `ios/RecztControl/Assets.xcassets/RecztSnowmanBody.imageset/paint.png`
- `ios/RecztControl/Assets.xcassets/RecztSnowmanFrontSkate.imageset/Contents.json`
- `ios/RecztControl/Assets.xcassets/RecztSnowmanFrontSkate.imageset/paint.png`
- `ios/RecztControl/Assets.xcassets/RecztSnowmanRearSkate.imageset/Contents.json`
- `ios/RecztControl/Assets.xcassets/RecztSnowmanRearSkate.imageset/paint.png`
- `ios/RecztControl/Assets.xcassets/RecztSnowmanScarf.imageset/Contents.json`
- `ios/RecztControl/Assets.xcassets/RecztSnowmanScarf.imageset/paint.png`
- `ios/RecztControl/RecztControlBundle.swift`
- `ios/RecztControl/RecztOpenIntent.swift`
- `ios/RecztControl/RecztRecognitionLiveActivity.swift`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/iOS 27 System Integration/RecztLiveActivityManager.swift`
- `ios/Runner/iOS 27 System Integration/RecztRecognitionAttributes.swift`
- `ios/RunnerTests/RunnerTests.swift`

### Tools and regression checks

- `scripts/install-halloween-update-macos.sh`
- `scripts/run-profile-macos.sh`
- `scripts/tests/test_halloween_installer.py`
- `scripts/tests/test_native_widget_contracts.py`
- `test/christmas_rig_render_test.dart`
- `test/music_intelligence_card_test.dart`
- `test/scene_energy_test.dart`
- `test/seasonal_scenes_test.dart`

### Notes and previews

- `docs/halloween-animation.md`
- `docs/previews/christmas-motion.mp4`
- `docs/previews/christmas-roof-snow.mp4`
- `docs/previews/christmas-skating.mp4`
- `docs/previews/halloween-details.mp4`
- `docs/previews/halloween-motion.mp4`
- `docs/previews/halloween-scene.png`
- `docs/previews/music-intelligence-compact.png`
- `docs/previews/music-intelligence-samples.png`
- `docs/seasonal-native-and-analytics-update.md`
- `docs/seasonal-softening-update.md`
