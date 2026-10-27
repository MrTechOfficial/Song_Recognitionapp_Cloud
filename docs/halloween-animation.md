# Halloween animation implementation

Halloween is the priority. Christmas/winter remains unfinished and is preserved
from the last delivered ZIP, commit 4da50fd6a7145e7e09079fc0739928a8edf0eb5f.
The requested later Christmas changes are recorded in
[seasonal-follow-ups.md](seasonal-follow-ups.md), not implemented in this pass.

The source is edited in the cloud copy of the existing project. The user
confirmed that the Mac project has the same code as that ZIP. The installer
applies these scoped changes to `/Users/georgeb/Documents/Reczt - Xcode` by default.

## What was inspected

`lib/main.dart` still selects `HalloweenLayeredSceneV2` for Halloween in the
Seasonal Theme Lab. Its older `_HalloweenAnimatedScene` implementation is not
called and is left alone. Existing v2 assets, the legacy Halloween assets,
controllers/timers, the theme selector and shared lifecycle/Reduce Motion gate
were inspected before implementation. No second scene is layered over the active
one, and the real Flutter controls still render above the decorative world.

The old v2 implementation already had perspective heads, a blink frame, pumpkin
faces, separate bat parts and some ambient motion. Its bats hovered in place,
leaves used an unrelated time loop, the tree was static because the old patch
contained opaque sky, and cloud movement did not control scene illumination.
The `moon.png` and `skeleton_body.png` files are empty placeholders; the moon and
body already painted into the background remain in use, with the separate head
perspectives animated above the existing body.

## Animation behavior

1. **Skeleton turns:** five existing painted front/partial-left/full-left/
   partial-right/full-right perspectives are blended in sequence. No flat Y/Z
   rotation is used. A gesture looks one way, lingers, returns to center, then
   glances the other way before resting. First gesture starts around 10–13
   seconds; later still intervals vary from 16–28 seconds, and gestures take
   5.6–7.1 seconds. Direction and strength vary.
2. **Blink:** the existing painted eyelids are aligned and extracted into an
   eye-only overlay. The skull's silhouette, nose, jaw and neck stay unchanged.
   A 190 ms close/brief hold/open happens on its own irregular schedule. Head
   turns defer if a blink is in progress; blink scheduling stops throughout a
   look gesture and resumes after a quiet pause. They never overlap.
3. **Bats:** occasional one- or two-bat flights enter beyond one side and exit
   beyond the other. Separate body and wing art flap at their hinges. Curved
   paths, flight duration, altitude, wing cadence, direction and size vary.
   Flights pass through or near the moon, with smaller second bats on some
   passes. First entry is around 5–8 seconds, followed by irregular gaps.
4. **Tree:** a true transparent foreground matte replaces the old opaque sky
   patch. A small triangle mesh bends the trunk/crown progressively, leaving the
   base rooted. The crown moves more than the lower trunk; each gesture sways
   both directions and settles. Durations, rests, direction and amplitude vary,
   with occasional stronger gusts. Static texture coordinates and mesh topology
   are cached; only vertex positions change during a sway. There is no visible
   wind-line animation.
5. **Every third sway:** only the tree controller's completed status increments
   the sway counter. Completion numbers 3, 6, 9, etc. release exactly one leaf.
   A leaf starts at a bough, drifts and flutters toward the ground, then fades.
   Origin, leaf artwork, size, drift and fall duration vary. Pausing preserves
   the counter and active fall. No elapsed-time leaf loop remains. First leaf
   normally appears after roughly 23–35 seconds of scene time.
6. **Pumpkin faces:** classic is the resting expression. Funny/surprised and a
   narrow closed-mouth classic expression alternate on irregular visits,
   returning to classic between them. The existing classic painting is warped
   locally to narrow its mouth while retaining the eyes, stem and silhouette.
   Crossfades last 320 ms; alternative faces stay for 3–5.5 seconds, with normal
   intervals generally 11–23 seconds. First change starts around 8–13 seconds.
7. **Candle:** each expression has its own alpha mask derived from its actual
   illuminated eyes/mouth. Warm brightness, small halo radius and intensity
   vary gently on an independent 43-second multi-frequency flicker track. The
   mask follows the current face, including during crossfades. The old circular
   orange glow blob is not used, and the pumpkin's whole body does not flash.
8. **Cloud and moon:** a painted cloud drifts on its own slow 180-second cycle,
   beginning just outside the moon area. Neutral checkerboard contamination in
   its old edge is removed in a derived cutout. An alpha map of this actual
   painted cloud is sampled over the moon's disc. Increasing coverage gradually
   shades the illustrated world, then releases the shade as the cloud passes.
   Maximum shade is capped at 11%; the actual cloud reaches the requested subtle
   5–12% range. Dimming is inside the decorative scene, below the real UI.
9. **Independent timing:** blink, look, tree, leaf, bat, cloud, candle and fog
   have separate controllers. Occasional actors use independent one-shot timers
   with randomized delays, not one shared repeating ambient clock. The existing
   ground fog remains very faint on its own long drift cycle.

## Lifecycle, accessibility and performance

The existing shared lifecycle gate is unchanged. When backgrounded or disabled
by a parent TickerMode, all eight controllers stop and all six waiting/reset
Timers are cancelled. Active gesture/fall phases remain frozen and continue on
resume. Waiting delays are rescheduled naturally rather than producing a burst
of missed events. Widget-owned transitions are also gated with TickerMode.

With Reduce Motion, the tree, front skull, classic pumpkin and lighting stay
static; flying bats, falling leaves, moving cloud and moving moon shade are
omitted. Candle intensity is fixed. The original illustrated look stays intact.

Assets are precached, animated areas use RepaintBoundary, and controller-driven
builders update individual decorative areas. Root setState is limited to initial
layer readiness and occasional expression changes. Mesh topology is cached.
Image codecs, owned image/shader handles, controllers and timers are disposed,
including asynchronous layer loading that finishes after a theme is removed.

## Complete file inventory

Modified:

- `lib/seasonal/halloween_scene_v2.dart` — active scene, independent scheduling,
  painted head/blink, mesh tree, bat/leaf actors, face/candle and moon shade.
- `test/seasonal_scenes_test.dart` — existing head test now observes painted
  perspective changes instead of expecting the removed flat transform.

New code, tests, tools and documentation:

- `lib/seasonal/halloween_motion.dart` — gesture, flight, sway-count and actual
  cloud-alpha/moon-coverage models.
- `test/halloween_motion_test.dart`
- `test/halloween_scene_test.dart`
- `test/halloween_assets_test.dart`
- `scripts/derive_halloween_layers.py` — reproducible derived-asset recipe;
  Pillow/numpy/OpenCV are developer tools only, not app dependencies.
- `scripts/install-halloween-update-macos.sh`
- `scripts/tests/test_halloween_installer.py`
- `scripts/repair-halloween-support-macos.sh` — standalone repair for the
  shared dependency omitted by the first installer; adds only the missing file.
- `scripts/tests/test_halloween_support_repair.py`
- `docs/halloween-animation.md` — this report.
- `docs/seasonal-follow-ups.md`
- `docs/previews/halloween-motion.mp4` — production screen browser recording.
- `docs/previews/halloween-details.mp4` — enlarged lower-scene crop of that same
  recording, useful for inspecting the skull, pumpkin and arriving leaves.

Eight new derived assets, all inside `assets/seasonal/halloween_v2/`:

- `background_tree_clear.png` — 406 × 696; hidden tree area cleared.
- `tree_isolated.png` — 406 × 696; actual transparent tree, not a sky rectangle.
- `moon_cloud_clean.png` — 420 × 111; existing painted cloud with a cleaner edge.
- `pumpkin_closed.png` — 115 × 96; closed-mouth classic expression.
- `pumpkin_classic_light_mask.png` — 115 × 96.
- `pumpkin_surprised_light_mask.png` — 115 × 96.
- `pumpkin_closed_light_mask.png` — 115 × 96.
- `skeleton_eyes_closed_overlay.png` — 84 × 88; only painted eyelids.

No original asset was modified or deleted. Compositing the derived clear
background and tree at rest is pixel-identical to the original background, which
is checked both by the derivation recipe and the Flutter asset test. Original
Christmas artwork/runtime, shared lifecycle code, main.dart, native Swift,
Dynamic Island, Siri, microphone/recognition, History and Analytics code,
dependencies and iOS project/signing configuration are unchanged.

## Checks and limitations

- Dart formatting: checked on every changed/new Dart file.
- 27 focused Flutter tests pass, including the existing Christmas regression
  suite, exact third-sway integration, decoded asset painting, blink/look
  exclusion, pause/resume, Reduce Motion, TickerMode, disposal, taps and small
  phone theme switching. Asset paths/capitalization and image decoding are tested.
- Changed Halloween files and tests: focused `flutter analyze --no-pub` is clean.
- Full-project `flutter analyze --no-pub`: 29 pre-existing warnings/info remain
  in main.dart; its strict command still exits nonzero. No introduced issues or
  errors remain. Unrelated existing warnings were not blindly changed.
- Production `lib/main.dart` web release build passes. The existing unrelated
  CupertinoIcons font warning remains in that browser build.
- Eight installer checks pass with Mac utilities substituted on Linux: complete
  scoped copies/backups, the real installed scene's recursive local-import
  dependency closure, preserved Christmas/native/config files and existing shared
  helper, missing input abort, stale Flutter path abort, and backup failure abort.
- Six standalone repair checks pass: verified helper installation, failed or
  invalid downloads, existing matching/different helpers, and stale build paths.
- Browser checks cover the actual production screen, theme selection/round trips,
  and pixel-identical skull/pumpkin/tree/moon patches under Reduce Motion.
- iOS build: **not run**. This cloud environment is Linux and has no Xcode or
  Apple SDK. Native-device frame rate, audio behavior and final appearance must
  be checked on the Mac/iPhone. The included videos are browser captures.

## Install and watch on iPhone

Download the new ZIP and extract it separately. Close Xcode. From Terminal in
that new extracted folder:

```bash
bash scripts/install-halloween-update-macos.sh
```

The default working folder is `~/Documents/Reczt - Xcode`. An optional first
argument selects another working project. The installer verifies that the
workspace's generated Flutter configuration actually builds that same folder,
backs up existing changed files to Desktop, records newly introduced files, and
copies only the two Halloween runtime files, eight derived assets and four Dart
test files, plus `lib/seasonal/seasonal_scene_support.dart` if missing. An existing
identical shared helper stays untouched; a differing helper stops installation
before any files are changed so local work can be reviewed. Christmas, main.dart,
native Swift, Pods, generated configuration,
project files, signing and pubspec are not overwritten. No Pods reinstall or new
app dependencies are needed. Stop/Run in Xcode rebuilds the existing asset-folder
bundle with the changed Dart graph.

### Repair the first installer without downloading the ZIP again

The first Halloween installer omitted `seasonal_scene_support.dart`. A project
without that file cannot resolve `SeasonalSceneState`/`SeasonalSceneCanvas`, which
also produces cascading errors about `mounted`, `motionEnabled`, `setState`,
`dispose`, etc. This is a Dart compilation failure, not a Pods error.

Run `scripts/repair-halloween-support-macos.sh` on the Mac. It defaults to the
same Documents project, checks the configured build path, downloads the original
unchanged helper from pinned commit `9bc4545bd04de0daaf0b382512c80fc567529274`,
verifies its SHA-256 and adds it only if absent. It never replaces an existing
helper and never modifies other files. Stop and Run in Xcode afterward. If the
expected helper already exists, the script reports that; an ongoing build failure
then needs the first error at the top of the log, not the cascading errors below.

In Xcode open the working Runner workspace, select your iPhone and Run. In Reczt,
open **App Preferences → Seasonal Theme Lab → Halloween → Save**. Watch for at
least a minute for the characters, or about two minutes for a complete slow
cloud covering/clearing pass:

- Bottom-right skull: separate quick eye blinks and slower painted left/right
  glances, with quiet pauses and no spinning image.
- Bottom-left pumpkin: classic, funny/surprised and closed-mouth expressions;
  warm flicker stays in the currently carved eyes/mouth.
- Tree: rooted gentle bending, returning through center and settling. Count the
  completed sways; one leaf begins only after numbers 3, 6, 9, etc.
- Sky/moon: occasional flapping bats cross from outside, while the cloud moves
  much more slowly. Illustrated scenery darkens gradually under the cloud and
  brightens again; controls stay crisp and tappable.
- Go Home/background the app, wait, then return: active motion continues and no
  missed-event swarm or leaf dump appears. Repeat with Reduce Motion enabled:
  the scene should look attractive and still.
- Switch to Standard or Christmas and back. Also check the existing History,
  Analytics, microphone recognition, Siri and Dynamic Island on the iPhone; their
  code is preserved, but this environment cannot exercise the device hardware.

Delivery remains on `seasonal-ui-update`, with `main` untouched and Actions
workflows still disabled. Upload commits include `[skip ci]`.
