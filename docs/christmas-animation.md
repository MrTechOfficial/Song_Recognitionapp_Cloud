# Christmas lake animation

Christmas keeps the blue frozen lake, moon/cabin composition, icy-white headings,
dark translucent cards and instruction backing. Halloween, shared scene lifecycle,
app assets, dependencies and iOS files are unchanged by this update.

## Current behavior

- The snowman is about 18% larger than the previous version: 64–144 artwork
  units, with perspective scaling preserved. He remains a small lake character.
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
- Individual string lights twinkle more visibly, beginning within a few seconds.
  They brighten separately rather than flashing the whole string.
- An occasional small chunk of snow slides down the cabin roof, falls under
  gravity, then disperses on the snowy bank. The first event starts around
  ten seconds into the scene and repeats after a long pause.
- Slow moving cloud wisps, a lateral breeze through the snowfall, faint chimney
  smoke, and small foreground twig movements add calm environmental motion.
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
4. Select Christmas. Observe for a minute and scroll the controls: the snowman
   should keep skating naturally on the lake, independently of your scrolling.

Current implementation files:

- `lib/main.dart` (Christmas spacing and host only)
- `lib/seasonal/christmas_scene.dart`
- `lib/seasonal/christmas_skating.dart`
- `lib/seasonal/christmas_weather.dart` (new)

The obsolete `christmas_scene_layout.dart` measurement module is removed. A
leftover local copy is unused, but replacing lib removes it cleanly.

## Validation

Eleven focused Flutter tests cover route bounds, velocity/stride continuity, depth,
individual twinkles, roof-snow physics, foreground hit testing, a synchronized
scroll regression, pause/resume, reduced motion, disposal, small-phone layout,
and existing Halloween behavior. Focused analysis and a production-entrypoint
web build are checked; unrelated existing main.dart warnings are left in place.
Native iPhone performance and the final feel still need an on-device check.

A browser recording of the production screen is available at
[`previews/christmas-motion.mp4`](previews/christmas-motion.mp4). Native fonts,
emoji and frame-rate rendering can differ from this browser capture.
