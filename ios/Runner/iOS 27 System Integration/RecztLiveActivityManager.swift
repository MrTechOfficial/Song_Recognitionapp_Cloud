import ActivityKit
import Foundation
@available(iOS 17.0, *)
actor RecztLiveActivityManager {
    static let shared = RecztLiveActivityManager()

    private var currentSessionID: String?

    @discardableResult
    func start(
        durationSeconds: Int,
        environment: String,
        source: String
    ) async throws -> String {
        // Keep one recognition Live Activity at a time.
        for activity in Activity<RecztRecognitionAttributes>.activities {
            let state = RecztRecognitionAttributes.ContentState(
                phase: "cancelled",
                title: "Reczt",
                artist: "Starting a new recognition",
                secondsRemaining: 0,
                source: source
            )
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        let sessionID = UUID().uuidString.lowercased()
        let attributes = RecztRecognitionAttributes(
            sessionID: sessionID,
            startedAt: Date(),
            environment: environment
        )
        let state = RecztRecognitionAttributes.ContentState.listening(
            secondsRemaining: durationSeconds,
            source: source
        )
        _ = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
        currentSessionID = sessionID
        return sessionID
    }

    func update(
        phase: String,
        secondsRemaining: Int? = nil,
        title: String? = nil,
        artist: String? = nil,
        source: String? = nil
    ) async {
        guard let activity = activeActivity() else { return }
        let old = activity.content.state
        let state = RecztRecognitionAttributes.ContentState(
            phase: phase,
            title: title ?? old.title,
            artist: artist ?? old.artist,
            secondsRemaining: secondsRemaining ?? old.secondsRemaining,
            source: source ?? old.source
        )
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func showResult(title: String, artist: String, source: String? = nil) async {
        guard let activity = activeActivity() else { return }
        let old = activity.content.state
        let state = RecztRecognitionAttributes.ContentState(
            phase: "found",
            title: title,
            artist: artist,
            secondsRemaining: 0,
            source: source ?? old.source
        )
        await activity.update(ActivityContent(state: state, staleDate: nil))
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(18))
        )
        currentSessionID = nil
    }

    func finish(phase: String, message: String? = nil) async {
        guard let activity = activeActivity() else { return }
        let old = activity.content.state
        let state = RecztRecognitionAttributes.ContentState(
            phase: phase,
            title: phase == "noMatch" ? "No match yet" : "Reczt",
            artist: message ?? old.artist,
            secondsRemaining: 0,
            source: old.source
        )
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(6))
        )
        currentSessionID = nil
    }

    private func activeActivity() -> Activity<RecztRecognitionAttributes>? {
        let activities = Activity<RecztRecognitionAttributes>.activities
        if let id = currentSessionID,
           let exact = activities.first(where: { $0.attributes.sessionID == id }) {
            return exact
        }
        return activities.first
    }
}
