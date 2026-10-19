# Reczt seasonal animation update

This is the source from your `New Folder With Items.zip`, with the seasonal changes applied. The original upload and the GitHub checkout were not overwritten.

## Open in Xcode

Use a separate folder for this copy. Flutter 3.47.2 is the version recorded in your upload and used for validation here.

From the project folder on your Mac:

```sh
flutter pub get --enforce-lockfile
cd ios
pod install
open Runner.xcworkspace
```

Open `Runner.xcworkspace`, not `Runner.xcodeproj`. Select your normal simulator or connected device and signing configuration, then run. Generated dependencies, Pods and machine-specific Flutter configuration are deliberately excluded from this ZIP and are recreated by these commands.

In App Preferences, select Midnight/Halloween or Holiday Lights/Christmas. Both themes remain available year-round in this test build. Test the normal application from `lib/main.dart`.

For an optional artwork-only preview with a theme switch, pause control and sample-control toggle, run from the project root:

```sh
flutter run -t lib/seasonal_preview.dart
```

The optional preview does not record audio or call the recognition backend. Xcode's normal Runner entrypoint still starts the full application.

## Changes

- Scenery and animation remain decorative layers underneath the actual Flutter controls, excluded from hit testing and accessibility navigation.
- Halloween keeps your existing illustration and character assets. Blinks and look-around gestures have separate varied schedules, cannot overlap, and pause when inactive. Head turns include eased holds and a restrained perspective tilt.
- Removed the moving opaque tree/sky patch that could create visible rectangular seams. Existing fog, bats, leaves and pumpkin expressions remain separate effects.
- Christmas uses a clean background without baked-in snowfall or interface elements. Your original background remains available in the assets folder.
- Your red-hatted snowman glides on a curved pond path, with depth scaling, gentle leaning, a soft reflection, and pauses/turns at either end. It uses one consistent character drawing rather than rapidly switching mismatched silhouettes.
- Added room between the Christmas environment cards and recording controls for the skating lane. Improved nighttime control contrast and duration badge readability.
- Every scene layer uses the same artwork coordinate system through responsive cropping. Reduced motion, TickerMode and app lifecycle pause controllers and gesture timers.
- No dependency declarations, lockfiles, native iOS source, or recognition/backend code were changed.

Modified original files: `lib/main.dart`, `lib/seasonal/halloween_scene_v2.dart`, `lib/seasonal/christmas_scene.dart`.
Added files: `lib/seasonal/seasonal_scene_support.dart`, `lib/seasonal_preview.dart`, `assets/seasonal/christmas/christmas_background_clean.png`, `test/seasonal_scenes_test.dart`, and this document.

## Validation

- All 7 targeted Flutter tests passed. They exercise responsive pond bounds, continuous turns, gesture separation, hit testing, reduced motion, app lifecycle, disposal, and the preview on a small phone.
- Analysis of the changed scene modules, preview and tests: no issues.
- The full app and the scene preview both compiled for web using an external web scaffold and the uploaded dependency lockfile. The scaffold and its build outputs are not part of this iOS source ZIP.
- Browser checks of the rendered scenes and full application reported no uncaught page errors.
- The full app analysis reports 23 existing warnings/deprecation notices in unrelated portions of `main.dart`; no errors.
- Web builds reported a CupertinoIcons font-family warning; no Cupertino icons were added by this update.
- A native iOS build, signing, physical-device frame rate, and live audio recognition have not been validated on this Linux machine. Please check animation feel and safe areas on your iPhone/simulator before release.

Run the focused tests from the project root:

```sh
flutter test test/seasonal_scenes_test.dart
```
