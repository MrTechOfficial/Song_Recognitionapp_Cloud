# Christmas lake animation

The current Christmas colors, frozen-lake illustration, moon/cabin composition,
translucent cards, white headings, and instruction backing are preserved.
Halloween code, shared scene lifecycle code, assets, dependencies and iOS files
are unchanged by this refinement.

## Motion

- A 96-second closed route visits the distant left, center, and right shoreline,
  passes behind the interface, then makes a brief nearer pass across open ice.
  It is deliberately intermittent rather than a continuously visible mascot.
- The snowman remains small: 54–122 units on the 941-unit artwork canvas, never
  exceeding the previous 128-unit maximum. Distance controls size, cadence,
  body lean, tiny push lift, contact shadow and reflection strength.
- Time-weighted spline tangents keep position and velocity continuous at every
  join. Nearer lateral passes move faster; distant stretches take longer.
- Both existing PNGs supply skate poses. The alternate legs are mirrored and
  feathered below a stable upper body, avoiding flickering faces and hats.
  Each push eases into a one-skate glide, with occasional longer coasts.
- The real environment cards and instruction panel report their rendered bounds.
  Those measurements guide the nearer pass through the available gap. Scrolling
  or resizing refreshes the measurements; route changes blend over 1.4 seconds.
  These markers do not move, restyle, intercept taps, or replace real controls.
- Far and near snow layers move at different speeds. Faint chimney smoke,
  very slow cloud wisps, individual light twinkles, and rare tiny foreground
  twig movement add atmosphere. The background itself never shifts as a whole.
- Existing app lifecycle, reduced-motion and ticker controls pause the scene.

Watch for at least a minute to see a near pass, the departure, and a distant
stretch. Some stretches are intentionally obscured by the foreground UI.

## Install this refinement on the Mac

The branch is `seasonal-ui-update`; `main` is untouched and GitHub Actions
workflow files remain outside `.github/workflows`.

Since this update changes only Dart source, you can keep the already working
Mac project's `ios` folder, Pods and generated Xcode settings:

1. Download the latest ZIP of `seasonal-ui-update` from GitHub and unzip it into
   a separate temporary folder.
2. Back up your working project. Copy the new ZIP's **lib folder** into that
   working project, replacing its old lib folder. If you have made additional
   local Dart edits, merge the files listed below instead of replacing lib.
3. In Xcode, stop the running app and run the working project's
   `ios/Runner.xcworkspace` again. No new packages or Pods are required.
4. Select Christmas in App Preferences and observe the scene for a minute.

Dart files in this refinement:

- `lib/main.dart` (Christmas host and invisible UI measurements only)
- `lib/seasonal/christmas_scene.dart`
- `lib/seasonal/christmas_scene_layout.dart` (new)
- `lib/seasonal/christmas_skating.dart` (new)

The updated focused tests are in `test/seasonal_scenes_test.dart`.

## Validation

Ten focused Flutter tests cover route/stride continuity, lake bounds across
phone/tablet/landscape sizes, depth cues, intermittent clear passes, foreground
hit testing, measured-layout stability, pause/resume, reduced motion, disposal,
and unchanged Halloween behavior. Focused analysis and a full-app web build
are also checked. Existing unrelated main.dart warnings are left in place.

The full-screen browser render is checked with the actual production interface.
Native iPhone frame rate and the final visual feel still require an on-device
check; this environment runs Linux and cannot perform an Xcode build.

A browser recording of the production screen is available at
[`previews/christmas-motion.mp4`](previews/christmas-motion.mp4). Native font,
emoji and frame-rate rendering may differ from this browser capture.
