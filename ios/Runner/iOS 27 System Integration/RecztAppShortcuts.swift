import AppIntents
import Foundation

@available(iOS 27.0, *)
struct ActivateRecztShortcutIntent:
    AudioRecordingIntent,
    LongRunningIntent,
    CancellableIntent {

    static let title: LocalizedStringResource = "Activate Reczt"

    static let description = IntentDescription(
        "Listen for singing, humming, or nearby music and identify the song with Reczt."
    )

    static var supportedModes: IntentModes {
        [.background]
    }
    
    static var allowedExecutionTargets: IntentExecutionTargets {
        [.main, .widgetKitExtension]
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        progress.totalUnitCount = 100
        progress.localizedDescription = "Listening for a song"

        let coordinator = RecztRecognitionCoordinator()

        let result = try await performBackgroundTask {
            try await coordinator.recognize(
                source: "System",
                progress: { completed, total, label in
                    let safeTotal = max(total, 1)
                    let fraction = min(
                        max(Double(completed) / Double(safeTotal), 0),
                        1
                    )

                    progress.completedUnitCount =
                        Int64((fraction * 100).rounded())

                    progress.localizedAdditionalDescription = label
                }
            )
        } onCancel: { _ in
            Task {
                await coordinator.cancel()
            }
        }

        progress.completedUnitCount = 100

        return .result(
            dialog: IntentDialog(
                full: "I found \(result.title) by \(result.artist).",
                supporting: "\(result.title) — \(result.artist)"
            )
        )
    }
}
