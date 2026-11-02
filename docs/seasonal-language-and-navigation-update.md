# Live language changes, shared scenery and seasonal Island details

This update follows `seasonal-native-and-analytics-update.md`.

The seasonal picker, Theme Lab heading, testing badge, preview explanation,
save hint, eight theme names and seven edition badges now resolve through the
15 canonical dictionaries. The picker previews the chosen language immediately;
saving changes the app, existing pages and edition bubble. Arabic also sets the
app's reading direction. The Polish confidence error previously contained Dutch;
it now has a Polish translation.

Recognition status stores a dictionary key, not an already-translated sentence.
This includes the confidence-score rejection, connection/server errors, enhanced
search and voice-choice statuses, so an existing error follows a language change.
Analytics and History listen to the app language without rebuilding the navigator.
Music Intelligence retains its compact fixed-height layout and read-only samples.

## Page changes

Seasonal routes fade their foreground content through the single persistent
scene. Route snapshots are disabled for those pages, so the painted background,
its animation clock and viewport remain stationary. Standard keeps its platform
slide. Reduce Motion bypasses the new fade.

## Scene refinements and event preview

The skeleton's neck anchor moves from (336,673) to (333,671) in artwork coordinates;
its head scale changes from .75 to .71. The Christmas boots/legs and restrained
weight movement return to the revision before the last test. The newer eye blinks
remain. A brief route-driven directional blend replaces the instantaneous mirror
change. Scarf, roof snow and weather remain in place.

Explicitly choosing Standard in App Preferences and saving now previews the
Halloween announcement every time, even outside the release dates or after it
has been seen. This is a temporary testing path. Startup/resume still follows
the existing campaign window and seen flag; merely resuming does not repeat it.

## Native Island

The expanded Island/Lock Screen ornament now uses painted evergreen, ribbon,
pinecone and lantern/leaf garlands, replacing the Canvas cable and dots. Small
snow/sparkle particles interpolate with the character during actual recording
and phase updates. These updates occur only while recognition is active, at most
once a second. There is no decoration-only repeating timer. WidgetKit may throttle
or omit animation; Reduce Motion shows a still pose.

Both the renderer and activity alert use dictionaries generated from the same
canonical Flutter translations, embedded in the existing shared attributes file.
The language travels in ContentState (optional for older data); changing Reczt's
language also refreshes a current activity. This supports an app language different
from the device language. The timer uses that locale for native formatting.

Accepted matches post the localized result before optional metadata/analytics
work and autoplay. The expanded result says “Song found!” and, when autoplay has
a usable destination, “Directing you now!”. Failure paths post the localized
no-match/error result instead of leaving a searching activity indefinitely.
An alerting update asks iOS to surface the outcome: apps cannot force automatic
Dynamic Island expansion. While Reczt stays open, the result is dismissed after
about three seconds. Leaving Reczt dismisses app-started activities immediately.

App foreground/background is tracked in Dart and native notifications. Every
app activity callback carries a session ID and a revision, so old metadata,
queue or failure callbacks cannot revive or end a later microphone run. Resuming
never starts an Island by itself. Native App Intents end their activity in their
own task rather than relying on a timer after the OS suspends them. As with other
Live Activities, exact alert/animation delivery and force-quit timing belong to iOS.

## Install and test

Extract this complete new ZIP separately from the working project, close any
Xcode/Terminal run session, then run `scripts/install-halloween-update-macos.sh`.
The default target remains `~/Documents/Reczt - Xcode`. The installer backs up
existing files and installs the new Dart helpers, matching native code/schema,
tests and native image sets together. It opens `ios/Runner.xcworkspace` afterward.
Signing, Pods, project files, dependencies and saved app data are preserved.
No GitHub Actions workflow is enabled or used.

The optional `scripts/run-profile-macos.sh` still finds the existing Flutter SDK
from Generated.xcconfig. Press `q` in an attached Flutter run to stop the session,
or Control+C if it does not respond. Once Terminal returns to its prompt there
is nothing to stop. The installed iPhone app can run without a USB connection.

Validation: **62 Flutter tests** and **23 Python installer/native delivery checks**
pass. The production and scene-preview release web builds pass. Analysis retains
29 existing main.dart issues and adds none. All six changed Swift files parse;
the generated native text matches every canonical dictionary. Native XCTest
adds language/legacy-state checks, but cannot run here.

The browser check changed the open picker to Spanish, saved it, opened Analytics,
and previewed the Standard announcement twice with the already-seen flag set.
The actual Christmas renderer was captured through the near-shore pass and turn;
both browser sessions completed without page errors.

Previews:

- [Live language picker](previews/settings-live-language.png)
- [Spanish Halloween edition badge](previews/halloween-spanish.png)
- [Repeated announcement in Spanish](previews/halloween-announcement-preview-spanish.png)
- [Navigation and language switching](previews/seasonal-navigation.mp4)
- [Restored skating pose and softer turns](previews/christmas-soft-turns.mp4)

Apple SDKs/Xcode are unavailable in this Linux environment: Swift syntax parsing
and native delivery/schema checks are not an iOS compilation or device test.
