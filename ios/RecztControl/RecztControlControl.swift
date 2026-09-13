import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct RecztControlControl: ControlWidget {

    static let kind = "com.lesliekanebazos.reczt.IdentifySongControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {

            ControlWidgetButton(
                action: OpenRecztIntent(target: .listen)
            ) {
                Label(
                    "Identify Song",
                    systemImage: "waveform"
                )
            }
        }
        .displayName("Reczt")
        .description("Identify the song playing around you.")
    }
}
