# Halloween animation revision

This revision follows the iPhone feedback: the skull floated above its body,
face dissolves did not feel animated, and several atmospheric effects were too
subtle. Halloween remains the priority. Christmas/winter remains unfinished;
its scene, artwork and native integration are preserved. Future winter requests
remain in [seasonal-follow-ups.md](seasonal-follow-ups.md).

## What changed and how to watch it

- **Attached skeleton:** the body is painted into the 406 × 696 background.
  The skull now shares that artwork's fixed neck joint at (330, 669), rather than
  following the screen edge. The jaw overlaps the painted neck. Its scale and
  pivot are independent of screen cropping, scrolling and the tree's movement.
- **Continuous skull animation:** one painted skull texture is projected through
  a rounded mesh. Gaze changes shift and foreshorten the face, with a small head
  inclination/nod and a fixed neck joint. There are no dissolving perspective
  PNGs or flat Y-axis flips. These are modest head turns, not a fully modelled
  3D skull or complete profile views.
- **Actual eyelid movement:** local mesh vertices close and reopen the painted
  eye sockets in 190 ms, preserving the skull outline and nose. Blinking and
  looking retain independent irregular schedules and never overlap. The first
  glance begins around 6–9 seconds, followed by longer quiet intervals.
- **Pumpkin expressions:** the original painted body stays in place. Contours
  traced from its actual carved eyes/mouth move continuously between a grin,
  surprise and a narrow smile. A gesture includes an eased opening, hold and
  return, with tiny planted squash/stretch. Separate occasional blinks close
  the apertures. There is no AnimatedSwitcher or whole-face fade. First
  expression begins around 4–7 seconds; a gesture takes 4.3–5.7 seconds.
- **Visible candlelight:** warm gradients fill the carved apertures, surrounded
  by dark cut edges and a small aperture-shaped glow. Four independent frequency
  components on an 11-second seamless track make the interior shift between
  dim amber and bright gold. The body does not flash. Rendered-pixel tests check
  that carved-eye brightness changes strongly while the outer skin stays still.
- **More tree movement:** ordinary sways use amplitudes 8–12, with occasional
  15–18 gusts. A mesh progressively bends the crown/trunk while the base remains
  rooted. Timing, direction and strength vary, with pauses and a settled return.
  Every third completed sway still releases exactly one drifting/fluttering leaf.
- **Slow graveyard fog:** three soft layers drift horizontally at different
  phases/heights, with a small vertical drift on a 110-second cycle. They use
  clean wisps derived from the painted cloud texture; the old fog's baked
  checkerboard is not used. Opacity is stronger but still translucent.
- **More bats:** groups of 3–5 bats cross the sky with staggered entry, varied
  altitude, width, curved paths and hinged wing flaps. Flights last around
  7–10 seconds, with 3–7 second rests after a group exits. First entry is around
  1.5–3 seconds. There are no missed-event bursts after backgrounding.
- **Layered clouds:** six clouds have different sizes, heights, starting phases
  and travel speeds. A broader, fuller painted bank crosses the moon, while
  smaller clouds move at other depths. Clouds wrap only when beyond the crop.
- **Noticeable moon shadow over the UI:** sampled alpha from the actual cloud
  artwork and each cloud's opacity determine moon coverage. Combined coverage
  eases into a maximum 30% night shade and releases as the moon clears. The
  Halloween host draws one IgnorePointer shade above both scenery and real UI;
  controls remain responsive. It is not an unrelated timed dark pulse.
- **Readable status text:** Halloween now uses the same status-box position,
  padding (14 horizontal, 8 vertical), 14-pixel corner radius, border and bold
  white text as Christmas, with a Halloween-colored translucent backing.
  Christmas's existing values and branch remain unchanged.

Watch for at least a minute to see the characters and tree/leaf rhythm, and
about two minutes to see the broad cloud cover and clear the moon. Look at the
bottom-right jaw/neck connection, pumpkin eye/mouth movement and its changing
interior light, graveyard fog and more frequent bat groups. The browser video
is an illustration preview, not a native-device performance measurement.

## Lifecycle, accessibility and performance

The existing shared lifecycle gate remains unchanged. All ten controllers stop
and all six gesture timers cancel when backgrounded or disabled by TickerMode.
Active gestures resume from their held progress; delays are rescheduled without
replaying missed events. The third-sway counter is retained. Controllers, timers,
image codecs, shader handles and owned images are disposed, including an asset
load that finishes after a theme switch.

Reduce Motion leaves the skull, pumpkin, tree, fog and lighting static and omits
moving clouds, bats and falling leaves. The full-screen shade clears completely.
All scenery and the shade ignore pointer events and are excluded from semantics.
Controller-driven builders repaint individual layers; cloud shading updates a
notifier without rebuilding the foreground widget tree. Mesh topology/UVs are
cached, and no new runtime dependencies or recognition/native code are added.

## Files changed in this revision

Modified source:

- `lib/main.dart` — Halloween host and status-box conditionals only.
- `lib/seasonal/halloween_scene_v2.dart` — scene, scheduling, fog/clouds and host.
- `lib/seasonal/halloween_motion.dart` — anchored skull mesh, expressions,
  stronger candle model, six cloud tracks and stronger coverage-based shade.

New source:

- `lib/seasonal/halloween_characters.dart` — continuous skull and pumpkin painters.
- `lib/seasonal/halloween_carvings.dart` — generated outlines of painted carvings.

Modified tests/tools:

- `test/seasonal_scenes_test.dart`
- `test/halloween_motion_test.dart`
- `test/halloween_scene_test.dart`
- `test/halloween_assets_test.dart`
- `scripts/install-halloween-update-macos.sh`
- `scripts/tests/test_halloween_installer.py`

New tests/tools:

- `test/halloween_rig_render_test.dart` — real rendered pixels: candle locality,
  moving carving shapes rather than a dissolve, and physically closing sockets.
- `scripts/derive_halloween_rig.py` — reproducible original-art derivation using
  Pillow/numpy/OpenCV as developer tools only.

Five new derived assets under `assets/seasonal/halloween_v2/`:

- `skeleton_skull_rig.png` — original skull with stray old neck/ground removed.
- `pumpkin_shell.png` — original painted body with the old carved face cleared.
- `fog_far_clean.png`
- `fog_near_clean.png`
- `moon_cloud_bank.png`

Documentation/previews updated:

- `docs/halloween-animation.md` — this report.
- `docs/previews/halloween-motion.mp4` — full production-screen browser recording.
- `docs/previews/halloween-details.mp4` — enlarged skull/pumpkin crop.

No existing artwork was overwritten or deleted. Christmas scene/artwork, the
shared lifecycle helper, dependencies, iOS project/signing/Pods, native Swift,
Siri, Dynamic Island and recognition code are unchanged. main.dart changes are
limited to the Halloween host and requested text backing.

## Validation and limits

- 33 Flutter checks pass, including rendered-pixel rig/candle tests, fixed neck
  geometry, continuous expressions, separate blinks, six cloud tracks/real-alpha
  coverage, UI shade/taps/Reduce Motion, lifecycle/disposal, third-sway integration,
  increased bat cadence, and existing Christmas/scroll/theme regression checks.
- 15 installer/repair checks pass on Linux with Mac utilities substituted:
  complete source/asset copies, recursive installed Dart import closure, backups
  before writes, preservation of Christmas/native/config, input/build-path checks
  and existing helper preservation. Missing existing Christmas imports stop the
  installer before main.dart changes.
- New/changed Halloween libraries and tests analyze clean. Full `flutter analyze`
  retains 29 pre-existing warnings/info in main.dart; no new errors or issues.
- The production main.dart web release builds. Its pre-existing CupertinoIcons
  font warning remains in the browser build.
- Production-browser checks cover theme switching, no asset/page errors and
  pixel-identical static regions with Reduce Motion.
- **iOS build not run here:** this environment is Linux without Xcode/Apple SDK.
  Final iPhone appearance, frame rate, microphone recognition, Siri, History,
  Analytics and Dynamic Island require a device check. Their logic is preserved.

## Installation

Extract the new GitHub ZIP separately in Downloads, close Xcode, and run its
`scripts/install-halloween-update-macos.sh`. It defaults to
`~/Documents/Reczt - Xcode`, or accepts another working project as its first
argument. The generated build path must match that folder.

The installer backs up all existing files it changes to Desktop before writing.
It now also installs main.dart for the explicitly requested Halloween UI changes,
all Halloween runtime dependencies (including generated carving data), five new
rig/atmosphere assets, prior derived Halloween layers and related tests. The shared
scene helper is added only if missing; an identical existing helper stays intact,
and a differing helper stops installation for review. Christmas files, native
Swift, Pods, generated settings and signing are preserved. No new dependencies or
Pods reinstall are required. Open the existing Runner workspace and Stop/Run.

In Reczt select **App Preferences → Seasonal Theme Lab → Halloween → Save**.
After watching the scene, try background/return, Reduce Motion, switching to
Christmas/Standard and back, and tapping the real buttons during moon dimming.

The earlier standalone `scripts/repair-halloween-support-macos.sh` only repairs
the shared helper omitted from the first installer; it does not install this
new animation revision. Delivery remains on `seasonal-ui-update`, with main
branch untouched, Actions workflows disabled and `[skip ci]` on upload commits.
