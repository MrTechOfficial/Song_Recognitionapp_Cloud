# Christmas Live Activity and Dynamic Island

Selecting Christmas in App Preferences also styles the **next recognition
session's Live Activity**. On supported iPhones this appears in the Dynamic
Island; the same session has a Christmas Lock Screen presentation.

The compact and minimal Island show a small vector snowman in a red hat and
scarf. The compact trailing side keeps the real listening countdown, searching
indicator or song-found checkmark. The expanded Island adds warm gold accents,
icy-white status/song text, and a string of colored lights. The Lock Screen
uses a dark winter-blue background, snowman badge and the same song details.

Garland highlights follow the existing countdown state updates. This does not
add timers, repeat animations or requests to keep decoration running while the
app is suspended. iOS controls Live Activity presentation and update frequency.

## Theme data

Flutter passes `seasonalTheme` when starting a recognition and when syncing its
settings to the existing App Group. Native shortcut/control recognitions read
the saved theme when creating their activity. Theme is an optional activity
attribute, fixed for the session, so results retain the session's styling.
Missing theme values in older settings/activities decode as nil and use the
existing non-Christmas presentation. The persisted language, environment,
duration and backend URL keep their previous values.

No new assets, packages, entitlements, signing settings, Xcode file references
or Pods are required. Five existing runtime Swift files are changed along with
the Dart bridge. Three native migration/round-trip tests are included in the
existing RunnerTests target.

## Install and check in Xcode

Use the installer in the downloaded ZIP:

```bash
bash scripts/install-christmas-update-macos.sh
```

Run it from the new extracted folder, with Xcode closed. It backs up lib and
the changed Swift/test files, then copies them into the working downloaded
project. An optional first argument can select a different working project.
It preserves the working Pods, generated Flutter configuration and signing.
**The previous lib-only update commands do not install the native Island UI.**

1. In Xcode, Run Runner on an iPhone/simulator that supports Dynamic Island.
2. In App Preferences, select Christmas. Start a new recognition, then go to the
   Home Screen while it listens. Check the compact snowman/countdown.
3. Long-press the Island to inspect the expanded presentation. Confirm searching
   and song-result text/checkmarks remain correct. Lock the phone to see the
   Christmas Live Activity.
4. To inspect all states without recording, open
   `ios/RecztControl/RecztRecognitionLiveActivity.swift` and enable Xcode's
   Canvas. Four `#Preview` entries cover expanded, compact, minimal and Lock
   Screen layouts, with listening/searching/found/no-match samples.
5. Switch to another app theme and start a new session to check the standard
   Island presentation. The prior session keeps its original theme.
6. Run RunnerTests to check old settings/activity decoding and Christmas
   attribute/settings round trips.

The cloud environment is Linux and cannot run Xcode, SwiftUI or ActivityKit.
Swift source syntax is checked here; native compilation, previews and the three
RunnerTests require Xcode on the Mac. The Flutter production screen is built and
visually checked separately; its browser video does not show the native Island.
