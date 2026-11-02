# Christmas Island layout and recognition outcomes

Christmas's expanded Island moves its headline out of the narrow center slot
and gives it a full-width row below the camera. The icon and timer stay at the
sides, and the painted garland is shallower. The existing Halloween layout is
preserved.

Both seasonal characters use aligned painted frown variants for a `noMatch`
result. A successful result triggers a small spring hop and a snowflake/sparkle
symbol bounce. These are state-driven WidgetKit animations with no idle loop;
iOS controls whether animations play, and Reduce Motion keeps still poses.
The existing activity lifetime, six-second result window and no-resurrection
session guards remain.

The app also fixes the incorrect confidence rejection described in
[backend-recognition-reliability.md](backend-recognition-reliability.md).
Installing the app update and deploying the existing Render backend are
separate steps. The scoped Mac installer supplies the new Dart policy and native
painted assets together; project files, signing, Pods and app data are preserved.

**80 Flutter tests, 17 backend tests and 23 installer/native resource checks pass.**
The release web build passes; analysis retains the same 29 existing main.dart
issues. Native Swift syntax/resource checks
do not replace an Xcode build or an iPhone test. Real provider accuracy and the
live Render service cannot be verified from this workspace.

Controlled app-flow screenshots: [confirmation](previews/recognition-confirmation-fixture.png)
and [accepted result](previews/recognition-accepted-fixture.png). They contain
mock recognition data, not a live provider result.
