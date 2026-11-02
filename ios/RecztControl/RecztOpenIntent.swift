import AppIntents
import Foundation

@available(iOS 18.0, *)
struct OpenRecztIntent: OpenIntent {
    static var title: LocalizedStringResource = "Identify Song"
    static var openAppWhenRun: Bool { true }
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Target")
    var target: RecztDestination

    init() {
        self.target = .listen
    }

    init(target: RecztDestination) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // This foreground intent runs in the app. Persist the trigger before
        // notifying so a cold Flutter engine can consume it exactly as Siri does.
        UserDefaults.standard.set(true, forKey: "flutter.launchedFromSiri")
        UserDefaults(suiteName: RecztSharedConstants.appGroupID)?.set(true, forKey: "reczt.control.startRecording")
        NotificationCenter.default.post(
            name: Notification.Name("reczt.control.identifySong"),
            object: nil
        )

        return .result()
    }
}

@available(iOS 18.0, *)
enum RecztDestination: String, AppEnum {
    case listen

    static var typeDisplayRepresentation =
        TypeDisplayRepresentation(name: "Reczt")

    static var caseDisplayRepresentations:
        [RecztDestination: DisplayRepresentation] = [
            .listen: DisplayRepresentation(
                title: "Identify Song"
            )
        ]
}
