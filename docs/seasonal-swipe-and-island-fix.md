# Back swipes, recognition lifetime and painted announcement

This revision supersedes the snowman turn blend and background-dismissal policy
in `seasonal-language-and-navigation-update.md`.

## Navigation

History and Analytics use `RecztPageRoute`. Seasonal button taps keep the fade
over the one stationary backdrop. Horizontal back swipes drive that same route
controller, so they can complete or cancel with the finger. Empty page areas
and the leading edge accept the gesture; child gesture recognizers and vertical
lists still participate in Flutter's gesture arena. The direction mirrors for
Arabic. The first route, modal overlays and routes that veto popping cannot start
the gesture. Standard retains iOS's native slide and edge swipe.

## Live Activity lifetime

Previously both Dart and native background notifications cancelled an active
app recognition. Viewing the Island outside Reczt could therefore remove it.
Background notifications now only gate new activity starts: the existing
session keeps listening/searching and may receive its result. Resume does not
start another activity. Explicit cancellation, Flutter detachment/disposal and
a delivered native termination notification still clear app activities.

Completed results remain for about six seconds before ending. An app-side result
gets a brief native background execution window to finish that dismissal when
autoplay opens a music app. Flutter receives the native reply immediately;
autoplay does not wait for the six-second window. Native App Intents wait through
their result window before ending. Ending with ActivityKit's `.after` policy
retains Lock Screen content but removes the Island immediately, so it is no
longer used to implement the result window.

Session/revision checks still reject duplicate or old app callbacks. An unscoped
native intent callback also cannot update/end a newer app session. iOS controls
visibility, expansion and forced-quit handling; exact delivery and background
time still need a physical-phone check. No timer creates an Island after completion.

## Artwork

The snowman is again one opaque painted figure throughout its route. The
mirrored-image crossfade and its scale adjustment are removed. The earlier boot
placement, gentle skating motion, scarf and blinks remain.

The event card's former CustomPainter moon, bats, bunting and pumpkins are
replaced by static image layers from the actual Halloween scene and painted
pumpkin. The scene copy lives inside the already-declared `halloween_v2` folder,
so the scoped installer can supply it without changing pubspec or dependencies.
All text keeps its existing 15-language dictionary entries. Explicit Standard
selection still repeats the announcement for testing.

## Verification and installation

**71 Flutter tests pass**, including completed/cancelled page swipes, scrolling,
RTL, first-route protection, the iOS Standard edge swipe, opaque snowman turns,
announcement images, background continuation, cancellation and stale callbacks.
The **23 installer/native-delivery checks** pass, as does the production web
release build. Analysis has the same 29 existing main.dart issues and no new
issues. Both changed Swift files parse and native localization export matches.
These checks do not compile ActivityKit/UIKit against Apple SDKs.

Previews: [painted announcement](previews/halloween-announcement-painted.png) and
[actual back swipes](previews/swipe-back-and-announcement.mp4).

The browser opened the actual History and Analytics screens and swiped both
back home, then displayed the painted announcement without page errors. The
preview browser serves its Roboto font from the SDK's local copy.

Extract the complete new source ZIP separately from your working project. Close
any Xcode run session and run `scripts/install-halloween-update-macos.sh` from
that download. It backs up the affected files, installs matching Dart/native
changes and the announcement assets, and opens the working Runner.xcworkspace.
No project, signing, Pods, saved app data or dependencies are replaced, and no
GitHub Actions workflow is enabled.
