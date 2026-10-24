# Christmas lake animation

Christmas keeps the blue frozen lake, moon/cabin composition, icy-white headings,
dark translucent cards and compact spacing. Halloween, shared scene lifecycle,
app assets and dependencies are unchanged. This update also adds Christmas
styling to the existing native Live Activity / Dynamic Island.

## Current scene behavior

- The snowman keeps his larger 104–228 artwork-unit size. His near turns move
  inward, and the closest pass is slightly farther from the front bank. The
  route leaves room for the whole character around the snowbanks and trees.
- The continuous 96-second course starts on a near-lake pass. A direct sine
  easing formula keeps perspective scale continuous, including at turns.
- The route depends exclusively on artwork and viewport crop. Scrolling or
  foreground button positions never move, resize or retarget the snowman.
- The compact Christmas layout retains 8-point card gaps and the 20-point gap
  before the instruction panel. Touch areas, typography and contrast remain.
- The skate poses blend below a stable upper body. Distance affects cadence,
  lean, push lift, shadow and reflection; pushes ease into longer glides.
- Individual string lights dim and brighten independently, with colored halos,
  warm-white cores and brief sparkles. The whole string never flashes together.
- Roof snow is about 38% smaller than the last version. Its ivory/cool-blue
  shading and faint contours match the roof cap. It slides off the front-right
  snowy edge, falls naturally, and joins a small shaded mound at the cabin bank.
  The impact flecks settle within 0.65 seconds. The resting pile remains instead
  of vanishing; a small impact swell settles back to its original height.
- The roof event starts at three seconds of scene time and repeats every 24
  seconds. The right-front location lets the fall and mound show beside the
  cards on a tall phone. On other crops, foreground UI may cover part of them.
- All three cloud layers travel at half their previous speeds. They wrap outside
  the artwork. The common weather clock is now 384 seconds so their loops meet
  smoothly with the snowfall, light, roof and wind schedules.
- Diagonal snowfall, occasional foreground powder gusts, a swaying twig and
  gentle chimney smoke remain. Reduced motion and app lifecycle/ticker controls
  pause characters and weather together.

## Christmas Dynamic Island

The existing recognition Live Activity gets a red-hat snowman badge, gold accents,
colored string lights and icy-white text when Christmas is selected. Compact,
minimal, expanded and Lock Screen presentations retain real recognition status,
countdown and song results. See [the native feature guide](christmas-dynamic-island.md)
for data flow, Xcode previews and device test steps.

## Update the working Mac project

The delivery branch is `seasonal-ui-update`; `main` is untouched. Actions remain
disabled and upload commits include `[skip ci]`.

1. Download the new project ZIP and extract it into a separate folder in Downloads.
2. Close Xcode. From Terminal in that new extracted folder, run:

   ```bash
   bash scripts/install-christmas-update-macos.sh
   ```

   The default working project is
   `~/Downloads/Song_Recognitionapp_Cloud-seasonal-ui-update`. If yours has moved,
   pass its path as the first argument. The installer checks all inputs, backs up
   lib and the changed native files to Desktop, then copies the new code. Existing
   Pods, generated Flutter configuration, signing and the Xcode project stay in
   place. No dependency updates or `pod install` are needed.
3. Xcode opens the working `ios/Runner.xcworkspace`. Select Runner and your device,
   then Run. Select Christmas and watch for 30 seconds to include a roof event.
4. Start a new recognition to check the themed Island / Lock Screen Live Activity.

**The previous lib-only commands do not install the native Island files.** This
installer copies the five changed runtime Swift files and RunnerTests as well.
If you have additional local edits to these files, merge them with the new source
instead of replacing them. The installer's backup retains the pre-update code.

## Validation

Thirteen focused Flutter tests cover route/scale continuity, clearance for the
larger near-lake sprite, perspective, independent twinkles, slower cloud travel,
roof-snow gravity and quick settling, foreground taps, synchronized scroll
independence, pause/resume, reduced motion, disposal and existing Halloween
behavior. Focused analysis is clean and the production Flutter entry point is
built for web. Existing unrelated main.dart warnings remain.

The production scene is inspected at phone size in the browser and recorded in
[`previews/christmas-motion.mp4`](previews/christmas-motion.mp4). This video shows
Flutter scenery; it does not render the native Dynamic Island. Native fonts,
emoji and frame rate can differ on iPhone.

Three installer checks use substituted Mac utilities to verify complete backups,
Dart/native updates, preserved Pods/configuration, and aborting before changes if
inputs or backups fail. Swift syntax is parsed here. Three native settings and
activity migration/round-trip tests plus four WidgetKit previews are included;
Xcode/SwiftUI/ActivityKit compilation, those tests and on-device Island rendering
must be checked on the Mac because the cloud environment is Linux.
