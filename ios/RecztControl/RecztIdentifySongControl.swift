import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 27.0, *)
struct RecztIdentifySongControl: ControlWidget {
    static let kind = "com.lesliekanebazos.reczt.identify-song"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(
                action: ActivateRecztShortcutIntent()
            ){
                Label("Identify Song", systemImage: "mic.fill")            } actionLabel: { isActive in
                Text(isActive ? "Listening…" : "Ready")
            }
        }
        .displayName("Identify Song")
        .description("Listen with Reczt and show the result in the Dynamic Island without opening the app.")
    }
}
