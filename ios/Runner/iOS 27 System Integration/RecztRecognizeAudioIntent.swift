import AppIntents
import Foundation

@available(iOS 27.0, *)
@UnionValue
enum RecztAudioItem {
    case song(RecztSongEntity)
    
    @available(iOS 27.0, *)
    @AppIntent(schema: .audio.recognizeAudio)
    struct RecztRecognizeAudioIntent: AudioRecordingIntent, LongRunningIntent, CancellableIntent {
        static let title: LocalizedStringResource = "Identify Song"
        static let description = IntentDescription(
            "Listen to singing, humming, or nearby music and identify the song with Reczt."
        )
        
        // Prefer a fully background experience. A WidgetKit control automatically
        // executes its AppIntent from the widget extension in the background.
        static var supportedModes: IntentModes { [.background] }
        static var allowedExecutionTargets: IntentExecutionTargets {
            [.main, .widgetKitExtension]
        }
        
        func perform() async throws -> some IntentResult
        & ReturnsValue<[RecztAudioItem]>        & ProvidesDialog {        progress.totalUnitCount = 100
            progress.localizedDescription = "Listening for a song"
            let coordinator = RecztRecognitionCoordinator()
            let result = try await performBackgroundTask {
                try await coordinator.recognize(
                    source: sourceLabel,
                    progress: { completed, total, label in
                        let safeTotal = max(total, 1)
                        let fraction = min(max(Double(completed) / Double(safeTotal), 0), 1)
                        progress.completedUnitCount = Int64((fraction * 100).rounded())
                        progress.localizedAdditionalDescription = label
                    }
                )
            } onCancel: { _ in
                Task {
                    await coordinator.cancel()
                }
            }
            
            progress.completedUnitCount = 100
            let entity = RecztSongEntity(result: result)
            return .result(
                value: [RecztAudioItem.song(entity)],            dialog: IntentDialog(
                    full: "I found \(result.title) by \(result.artist).",
                    supporting: "\(result.title) — \(result.artist)"
                )
            )
        }
        
        private var sourceLabel: String {
            // The same intent powers Siri, Shortcuts, Control Center, widgets and
            // the Action button. The result appears through the Live Activity / Dynamic Island.
            "System"
        }
    }
}
