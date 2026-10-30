import AppIntents
import SwiftUI
import WidgetKit

private struct RecztQuickIdentifyEntry: TimelineEntry {
    let date: Date
}

private struct RecztQuickIdentifyProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecztQuickIdentifyEntry {
        .init(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (RecztQuickIdentifyEntry) -> Void) {
        completion(.init(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecztQuickIdentifyEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: Date())], policy: .never))
    }
}

@available(iOS 27.0, *)
struct RecztQuickIdentifyWidget: Widget {
    let kind = "com.lesliekanebazos.reczt.quick-identify"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecztQuickIdentifyProvider()) { _ in
            VStack(spacing: 10) {
                Image(systemName: "waveform.badge.mic")
                    .font(.title)
                    .foregroundStyle(.orange)

                Text("Reczt")
                    .font(.headline)

                Button(intent: ActivateRecztShortcutIntent()) {                    Label("Identify", systemImage: "waveform.badge.mic")                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Identify")
        .description("Sing or hum from the widget. Reczt returns the result through the Dynamic Island.")
        .supportedFamilies([.systemSmall])
    }
}
