# Seasonal animation, event and energy update

This revision addresses the Halloween corrections, widget identification symbols,
once-only Halloween announcement, Christmas skating/wind, and idle resource use.
The winter scene remains work in progress; later roof-direction work is recorded
in [seasonal-follow-ups.md](seasonal-follow-ups.md).

Previews: [Halloween full screen](previews/halloween-motion.mp4),
[Halloween character detail](previews/halloween-details.mp4),
[Christmas skating detail](previews/christmas-skating.mp4),
[English announcement](previews/halloween-announcement.png), and
[Arabic announcement](previews/halloween-announcement-ar.png).

## Resource and lifecycle changes

A settings change previously pushed another `MyApp`/MaterialApp into the existing
navigator. Its old app-level seasonal background could remain underneath the new
one, leaving hidden animations and textures alive after theme switches. Settings
now update one stateful app root, with a stable navigator. The foreground screen
and its recording state stay in place. A regression switches themes 12 times and
checks one MaterialApp, one preserved foreground state and at most one seasonal
clock (zero in Standard). Preferences, legal/manual onboarding and the event
announcement are sequenced without reconstructing the app.

Halloween now uses one paced timer and retained painter instead of ten display
controllers, six gesture timers and per-frame widget trees. Its gesture schedule
is a small bounded scene model. Christmas uses the same paced clock. Both isolate
the foreground controls with repaint boundaries.

Decoration budgets:

| State | Maximum decoration updates |
| --- | --- |
| Active, normal power | 24 fps |
| No interaction for 45 seconds | 12 fps |
| Recording/searching or Low Power Mode | 12 fps |
| Native serious thermal state | 8 fps |
| Native critical thermal state | Static; decorative UI shade clears |
| App background, disabled TickerMode, Reduce Motion | Paused/static |

Touch or scroll restores the active budget when the device permits. These limits
apply to scenery; they do not throttle recognition, the real controls or audio.
The iOS bridge uses public ProcessInfo power/thermal notifications, not polling.
Gesture time freezes on pause; missed events never play back in a burst.

Further savings:

- Cloud alpha coverage is sampled into a 257-entry lookup once per viewport,
  rather than rescanning cloud alpha maps every display frame.
- Halloween uses a single scene painter and a direct translucent color overlay,
  with no full-screen Opacity save layer or candle blur/glow loop.
- The tree mesh is 8 × 14 cells, with offsets calculated once per row. The skull
  uses a smaller mesh during gestures and a plain cached image at rest.
- The painted pumpkin has no continuous controller, shape morph or body pulse.
- The Halloween decoded texture pool is about 4.19 MB. Images/shaders are owned
  and disposed; the pool does not grow with elapsed scene time.
- Four 400 × 400 snowman layers total 2.56 MB decoded. They replace rendering
  multiple masked copies of the original large PNGs. Reflection uses one small
  torso image, without the previous stacked ShaderMasks.
- Scene clocks, policy listeners, waiting timers, codecs, shaders and images are
  released on disposal, including an asset load that finishes after a switch.

A desktop Chromium spot check of the paced renderer measured 24.35 browser frames
per second while active and 12.05 after the idle timeout. Main-thread task time
for separate 20-second active/idle samples was 1.6962 s / 0.8111 s. A separate
clean-start comparison with the previous renderer measured 1.9380 s versus
1.6245 s of main-thread task time over 20 seconds, with JS heaps of 27.36 MiB
versus 23.45 MiB. These are Linux browser observations, not iPhone CPU, native
memory, energy or temperature measurements.

## Halloween behavior

- **Head placement:** the painted neck anchor moves eight artwork pixels right
  and four down, to (338, 673), keeping it independent of scrolling/cropping.
  The existing continuous skull turn and occasional eye blink remain.
- **Calm painted pumpkin:** the original classic, surprised and sly artwork is
  used directly. Normal faces are held for 35–55 seconds; an alternative visits
  briefly. No procedural candle/face, mouth-light animation or body deformation
  is drawn. Eye-only masks allow a short 0.95-second dip/twinkle, then long
  28–45 second quiet intervals. Most of the time the face is completely static.
- **Bats rebuilt:** connected body, ears and wing membranes are drawn together.
  Wings fold and extend with curved fingers/scallops; there are no separate
  rotated wing PNGs. Groups of 2–4 follow varied curved flights across the sky.
  The old static painted bat is removed from the rebuilt sky plate.
- **All sky layers move:** six cloud banks extracted from the original painting
  drift at different rates, with feathered edges. The background no longer
  retains their stationary copies. A larger dark painted bank covers the moon
  on a 62-second crossing cycle. Actual alpha coverage controls the shade,
  reaching up to about 39% over the scenery and functional UI. It clears as the
  moon clears and never intercepts taps.
- **Lower fog:** three translucent wisps sit among the graves, fence and ground
  at artwork heights 568, 612 and 650, with slow horizontal drift.
- **Stronger rooted sway:** tree amplitudes vary from 23–32. The crown bends
  visibly while the base stays planted. A leaf now releases only after every
  ninth completed sway, roughly every 1.5–2 minutes, rather than every third.
- **Filled image edges:** new background plates extend neighboring paint through
  the uploaded images' white edge pixels. Dark host backings also cover loading
  and sampling gaps. Original PNGs are retained.
- **Divider removed:** the grey divider between the icon menu and “Where Are You”
  is omitted in both Halloween and Christmas. Standard retains its divider.

## Christmas skating and wind

The original painted snowman is separated into a torso, two skates and scarf tail.
The skates alternate support and push, with smooth outward movement, lift and
ankle rotation. Short snow-colored leg joints stay connected as the boots move.
The torso shifts its weight; the scarf has its own anchored travelling wave.
There are no fading whole-body poses. The opening phase favors a near-left pass.
The existing depth-dependent lake route, bank margins and scroll independence
remain. Scarf timing joins at the long scene-loop boundary.

Four deterministic, varied wind-flurry tracks visit different heights and both
horizontal directions. Flecks and small wisps fade through each gust, rather
than repeating at the same two bottom-screen positions. Existing lights, clouds,
roof snow, pond depth and seasonal Dynamic Island layout remain available.

## Identification widget symbols

Control Center identification controls, the Home Screen quick-identify button,
and compact Live Activity identification use `waveform.badge.mic`: the waveform
with a small microphone badge. The symbol is available on the controls' supported
iOS versions. Recognition actions and status/result indicators are preserved.
A one-time WidgetKit timeline/control refresh requests the updated icons after
installation; continuous pulsing of the microphone symbol is removed.

## Once-only Halloween announcement

The campaign runs **October 29–November 2, 2026 inclusive, in device local time**.
It is eligible on Standard, after preferences/legal/manual onboarding, on startup
or a later foreground resume. It waits while recording/searching or another route
is in front. Opening before the event does not consume the announcement.

The English copy is “The Halloween Update Is Here!” with a festive illustrated
moon and bats. “Check out the design” saves and opens Halloween on the existing
app root. “Ok” keeps Standard. The shown flag is persisted before presenting, so
neither choice nor restarting shows it again for this campaign. This is once per
installation, using the existing preferences store; no remote service is added.

All four strings are added to all 15 existing dictionaries: English, Spanish,
French, German, Italian, Portuguese, Japanese, Korean, Chinese, Hindi, Russian,
Turkish, Arabic, Dutch and Polish. Arabic announcement layout is explicitly RTL.

## Validation and device limits

All 40 Flutter tests pass, including tests for rendered eye-only flicker, real skate/scarf
movement, rare gestures, exact ninth-sway releases, source asset decoding/edges,
clock/thermal/audio budgets, a simulated ten-minute idle/cache check, pause/resume,
Reduce Motion, taps during dimming, root/navigator lifetime, all event translations,
campaign boundaries/once-only persistence and the existing winter route checks.
All 17 installer/repair checks pass, covering backups before writes, every local Dart import from the
installed main.dart, new images, native inputs, build paths and protected config.

Production browser checks cover fresh-install preferences/legal/manual/event ordering,
a later eligible foreground resume after opening before the event, theme round trips,
static Reduce Motion regions, and English/Spanish/Arabic event buttons and persistence.
Videos are browser captures; the skating detail uses the existing scene preview so
the functional controls do not obscure the feet.
The native Swift files parse successfully, but this environment is Linux: **the
iOS build and native WidgetKit/thermal behavior cannot be exercised here**. Test
CPU, energy, memory and temperature on the iPhone in Profile/Release with Xcode
Instruments. The code changes and browser checks do not establish a particular
native CPU percentage or guarantee a phone temperature.

Full `flutter analyze` retains the 29 pre-existing main.dart warnings/info, with
no introduced issues. The focused changed modules/tests analyze clean. The web
release build retains its pre-existing CupertinoIcons font warning.

## Installation

Download and extract the new GitHub source ZIP separately, close Xcode, then run
its `scripts/install-halloween-update-macos.sh`. The default working project is
`~/Documents/Reczt - Xcode`; an optional first argument chooses another project.

The installer verifies that Generated.xcconfig builds that actual folder, checks
required existing scene/native files and asset declarations, backs up every
existing file it replaces to Desktop, and records new files. It now intentionally
updates the requested Christmas modules and five native icon/energy files as well
as Halloween, main.dart and tests. The shared lifecycle helper is added if missing,
kept if identical, and preserved for review if different. Dependencies, Pods,
generated config, project files, signing and entitlements are not replaced.

Stop and Run in Xcode so native/widget changes rebuild. To inspect the event,
select Standard during its window; the announcement is deliberately once-only.
Watch Halloween for a full moon pass and around two minutes for a rare leaf.
Check Christmas's alternating feet and scarf, then background/return, Reduce
Motion, Low Power Mode, and repeated theme changes. Existing recognition, Siri,
History, Analytics and Dynamic Island actions still need their device checks.

Delivery stays on `seasonal-ui-update`; the main branch and disabled Actions
workflows are preserved. Upload commits include `[skip ci]`.

## Complete file inventory

This delivery changes or adds 51 files. Original source artwork, dependency
locks, Xcode project/configuration, signing and disabled workflows are preserved.

### Flutter runtime

- `lib/main.dart` (updated)
- `lib/seasonal/christmas_scene.dart` (updated)
- `lib/seasonal/christmas_skating.dart` (updated)
- `lib/seasonal/christmas_weather.dart` (updated)
- `lib/seasonal/halloween_bats.dart` (added)
- `lib/seasonal/halloween_characters.dart` (updated)
- `lib/seasonal/halloween_event.dart` (added)
- `lib/seasonal/halloween_motion.dart` (updated)
- `lib/seasonal/halloween_scene_v2.dart` (updated)
- `lib/seasonal/halloween_timeline.dart` (added)
- `lib/seasonal/scene_frame_clock.dart` (added)

### Native iOS

- `ios/RecztControl/RecztControlControl.swift` (updated)
- `ios/RecztControl/RecztIdentifySongControl.swift` (updated)
- `ios/RecztControl/RecztQuickIdentifyWidget.swift` (updated)
- `ios/RecztControl/RecztRecognitionLiveActivity.swift` (updated)
- `ios/Runner/AppDelegate.swift` (updated)

### Derived artwork

- `assets/seasonal/christmas/christmas_background_edge_fill.png` (added)
- `assets/seasonal/christmas/snowman_body_rig.png` (added)
- `assets/seasonal/christmas/snowman_scarf_tail.png` (added)
- `assets/seasonal/christmas/snowman_skate_back.png` (added)
- `assets/seasonal/christmas/snowman_skate_front.png` (added)
- `assets/seasonal/halloween_v2/background_living_sky.png` (added)
- `assets/seasonal/halloween_v2/pumpkin_classic_eyes_mask.png` (added)
- `assets/seasonal/halloween_v2/pumpkin_sly_eyes_mask.png` (added)
- `assets/seasonal/halloween_v2/pumpkin_surprised_eyes_mask.png` (added)
- `assets/seasonal/halloween_v2/sky_cloud_0.png` (added)
- `assets/seasonal/halloween_v2/sky_cloud_1.png` (added)
- `assets/seasonal/halloween_v2/sky_cloud_2.png` (added)
- `assets/seasonal/halloween_v2/sky_cloud_3.png` (added)
- `assets/seasonal/halloween_v2/sky_cloud_4.png` (added)
- `assets/seasonal/halloween_v2/sky_cloud_5.png` (added)

### Installer and derivation tools

- `scripts/derive_seasonal_layers.py` (added)
- `scripts/install-halloween-update-macos.sh` (updated)

### Automated checks

- `scripts/tests/test_halloween_installer.py` (updated)
- `test/christmas_rig_render_test.dart` (added)
- `test/halloween_assets_test.dart` (updated)
- `test/halloween_event_test.dart` (added)
- `test/halloween_motion_test.dart` (updated)
- `test/halloween_rig_render_test.dart` (updated)
- `test/halloween_scene_test.dart` (updated)
- `test/scene_energy_test.dart` (added)
- `test/seasonal_scenes_test.dart` (updated)
- `test/widget_test.dart` (updated)

### Documentation and previews

- `docs/halloween-animation.md` (updated)
- `docs/previews/christmas-skating.mp4` (added)
- `docs/previews/halloween-announcement-ar.png` (added)
- `docs/previews/halloween-announcement.png` (added)
- `docs/previews/halloween-details.mp4` (updated)
- `docs/previews/halloween-motion.mp4` (updated)
- `docs/seasonal-follow-ups.md` (updated)
- `docs/seasonal-performance-update.md` (added)
