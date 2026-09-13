import AppIntents
import Foundation

@available(iOS 18.0, *)
struct OpenRecztIntent: OpenIntent {
    static var title: LocalizedStringResource = "Identify Song"

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
