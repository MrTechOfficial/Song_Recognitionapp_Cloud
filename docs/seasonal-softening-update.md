# Seasonal motion refinement and Dynamic Island characters

This revision follows the requested gentler Halloween motion, painted pumpkin
morph, subtle alternating skating, left-side cabin snow pile, festive event card,
and matching seasonal Dynamic Island characters.

## Halloween

- **Moon-shaped artifact removed.** The first two extracted cloud strips contained
  a circular cutout of the old moon. The scene now uses clean, flatter painted
  clouds in those positions and does not load the two affected strips.
- **Softer, slower sky.** Higher-quality texture sampling softens enlarged paint.
  Cloud drift is about 40% slower. Lower banks are more translucent, and ground
  fog is reduced to 6.5%, 7.5% and 3.5% opacity so graves remain visible.
- **Less frequent dimming.** The larger bank has one crossing in a 180-second
  cycle, followed by a long clear-sky gap. Its actual alpha coverage still drives
  the UI shade; the maximum is now about 27% instead of about 39%.
- **Real painted-face morph.** The eyes and mouth use matching radial landmarks.
  Original painted textures warp with the carving outlines over 1.15 seconds.
  Paint colors blend after the geometry aligns; there is no dissolve between two
  stationary faces. The stem and outer silhouette stay still. All three face
  pairs have a verified fold-free mesh. The rare eye-only flicker is retained.
- **Calmer bats and tree.** Bats take 10–15 seconds per crossing, with gentler
  wingbeats, independent directions, altitudes, delays and smooth wandering.
  The rooted tree bends with amplitudes 10–15 over 8–11 seconds, roughly half
  the previous strength. Leaves still release only after every ninth sway.
- **Smaller head.** The skull scale changes from .94 to .79 around the same fixed
  neck anchor, with higher-quality sampling for both the resting image and mesh.
- **Festive announcement.** Paper bunting, small smiling pumpkins, bats and
  sparkles frame the warm moon. The existing localized copy and two actions are
  preserved. The October 29–November 2 local-date window and saved once-only
  campaign flag are unchanged, so existing users are not shown it repeatedly.

## Christmas

Both skate blades are brought closer to a common ice-contact plane. The pushing
boot moves only a little while the opposite boot stays planted; support alternates.
The previous large kick, torso swing and bounce are reduced. The scarf travels
more slowly and gently. The fixed lake route and scroll independence remain.

The roof snow now follows the actual **left** gable slope: artwork coordinates
(821, 591) to the eave at (743, 666), then drops beside the cabin at (733, 731).
The first slide starts around three seconds after the scene begins and lands
around 5.4 seconds. A little mound grows at impact, stays on the snowbank, then
gradually settles back before the next fall. The sequence repeats every 24
seconds. A production-painter render check verifies that the pile visibly forms.

## Native seasonal characters

Both themes now cover the expanded, compact and minimal Dynamic Island, plus the
Lock Screen Live Activity:

- **Halloween:** an amber pumpkin with carved eyes and a small folded-wing bat,
  plum background, warm border color and purple/orange trim.
- **Christmas:** a snowman with red cap, shifting scarf and tiny alternating
  blades, navy background, snow-white paint and red/green/gold lights.

Brief 0.42-second interpolations follow the existing recognition countdown and
phase updates. There is no decoration timer, repeating animation loop, extra
Live Activity request or background update schedule. Reduce Motion uses a still
pose. WidgetKit controls native animation delivery and can suppress motion;
continuous animation in an idle Dynamic Island is not promised.

Result, error and countdown indicators remain alongside the characters. The
recognition actions, audio handling and queue are preserved. Eight Xcode previews
in `RecztRecognitionLiveActivity.swift` cover both themes and all four layouts.

Six new copy keys are added to all 15 existing Flutter dictionaries. Native
headlines, hints and countdown accessibility copy are exported from those
dictionaries, using the saved app language, with Arabic layout direction. Run
`python3 scripts/sync_activity_localizations.py --check` to verify the export.
Embedding the copy in the existing widget file avoids new Xcode resource entries.

## Energy and lifecycle

The shared 24 fps active / 12 fps idle decoration budget, recording/Low Power
limits, thermal limits, pause-on-background and stable single app root remain.
The pumpkin allocates a small mesh only during its brief transition. Shaders and
decoded images are owned by the scene and disposed on theme changes. The two
unused cloud strips are no longer decoded. Native character motion uses existing
ActivityKit updates, rather than extending the app's idle work.

## Validation

- All **45 Flutter tests** pass, including rendered morph-versus-dissolve checks,
  smooth morph endpoints, no folded triangles, small alternating boot motion,
  visible left-side snow pile, event translations and the previous lifecycle,
  scroll, memory, shade-tap and energy-budget regressions.
- All **18 installer/repair checks** pass, including older working folders missing
  the Christmas helpers and installation of matching native seasonal files.
- Production and scene-preview web release builds pass. The focused modules and
  tests analyze clean; full analysis retains the existing 29 main.dart issues.
- Native Swift syntax and localization export are checked. Xcode/Apple SDKs are
  unavailable on this Linux machine, so native compilation, WidgetKit animation,
  actual iPhone heat and the new native XCTest still need device/Xcode checks.

Preview videos are browser captures. The winter detail uses the scene preview to
keep functional controls from covering the cabin and boots. The Arabic browser
image uses an installed Arabic-capable fallback font; native text uses iOS fonts.

## Install and review

Use the new ZIP as a separate extracted source folder, close Xcode, then run
`scripts/install-halloween-update-macos.sh`. It backs up affected files to Desktop,
adds missing helpers, copies matching native sources and opens the working
`~/Documents/Reczt - Xcode/ios/Runner.xcworkspace`. Native regression tests are
included. Dependencies, signing, Pods, generated config and project files stay
in the working folder.

Run Runner on the iPhone. Check the first roof fall at about 3–6 seconds, the first
pumpkin morph around 38 seconds, and the slower moon pass. Trigger recognition
in each theme to inspect the corresponding native character. Users who already
saw the Halloween announcement keep their seen flag; review the supplied image
to inspect its updated art without resetting preferences.

## Previews

- [Halloween full screen](previews/halloween-motion.mp4)
- [Pumpkin morph and head detail](previews/halloween-details.mp4)
- [Christmas full scene](previews/christmas-motion.mp4)
- [Subtle skating detail](previews/christmas-skating.mp4)
- [Left-side roof fall and pile](previews/christmas-roof-snow.mp4)
- [Festive announcement](previews/halloween-announcement.png)
- [Arabic announcement](previews/halloween-announcement-ar.png)
- [Halloween still](previews/halloween-scene.png)

The browser checks also pass for stable Reduce Motion regions, repeated theme
switching, both announcement actions, and once-only persistence after reload in
English, Spanish and Arabic. No page errors were observed.

## Files in this refinement

This refinement changes or adds 37 files relative to the installer repair.

### Flutter runtime

- `lib/main.dart`
- `lib/seasonal/christmas_scene.dart`
- `lib/seasonal/christmas_skating.dart`
- `lib/seasonal/christmas_weather.dart`
- `lib/seasonal/halloween_carvings.dart`
- `lib/seasonal/halloween_characters.dart`
- `lib/seasonal/halloween_event.dart`
- `lib/seasonal/halloween_motion.dart`
- `lib/seasonal/halloween_scene_v2.dart`
- `lib/seasonal/halloween_timeline.dart`

### Native implementation and XCTest

- `ios/RecztControl/RecztRecognitionLiveActivity.swift`
- `ios/Runner/iOS 27 System Integration/RecztRecognitionAttributes.swift`
- `ios/RunnerTests/RunnerTests.swift`

### Developer tools and installer checks

- `scripts/derive_halloween_rig.py`
- `scripts/derive_pumpkin_morph.py`
- `scripts/install-halloween-update-macos.sh`
- `scripts/sync_activity_localizations.py`
- `scripts/tests/test_halloween_installer.py`

### Flutter regression checks

- `test/christmas_rig_render_test.dart`
- `test/halloween_assets_test.dart`
- `test/halloween_event_test.dart`
- `test/halloween_motion_test.dart`
- `test/halloween_rig_render_test.dart`
- `test/halloween_scene_test.dart`
- `test/seasonal_scenes_test.dart`

### Documentation and captures

- `docs/halloween-animation.md`
- `docs/previews/christmas-motion.mp4`
- `docs/previews/christmas-roof-snow.mp4`
- `docs/previews/christmas-skating.mp4`
- `docs/previews/halloween-announcement-ar.png`
- `docs/previews/halloween-announcement.png`
- `docs/previews/halloween-details.mp4`
- `docs/previews/halloween-motion.mp4`
- `docs/previews/halloween-scene.png`
- `docs/seasonal-follow-ups.md`
- `docs/seasonal-performance-update.md`
- `docs/seasonal-softening-update.md`
