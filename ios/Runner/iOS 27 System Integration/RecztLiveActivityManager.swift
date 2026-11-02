import ActivityKit
import Foundation

@available(iOS 17.0, *)
actor RecztLiveActivityManager {
    static let shared = RecztLiveActivityManager()
    private var currentSessionID: String?
    private var appIsForeground = true
    private var lifecycleRevision = 0
    private var dismissalTask: Task<Void, Never>?

    @discardableResult
    func start(durationSeconds: Int, environment: String, source: String,
               seasonalTheme: String? = nil) async throws -> String {
        let revision = lifecycleRevision
        guard source != "app" || appIsForeground else { throw CancellationError() }
        dismissalTask?.cancel()
        for activity in Activity<RecztRecognitionAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        // An app-background notification can arrive during the await above.
        guard source != "app" || (appIsForeground && revision == lifecycleRevision) else {
            throw CancellationError()
        }
        let sessionID = UUID().uuidString.lowercased()
        let settings = RecztSharedStore.shared.recognitionSettings()
        let attributes = RecztRecognitionAttributes(
            sessionID: sessionID, startedAt: Date(), environment: environment,
            seasonalTheme: seasonalTheme ?? settings.seasonalTheme)
        let state = RecztRecognitionAttributes.ContentState.listening(
            secondsRemaining: durationSeconds, source: source, language: settings.language)
        _ = try Activity.request(attributes: attributes,
            content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(Double(durationSeconds + 60))),
            pushType: nil)
        currentSessionID = sessionID
        return sessionID
    }

    func update(phase: String, secondsRemaining: Int? = nil, title: String? = nil,
                artist: String? = nil, source: String? = nil, sessionID: String? = nil) async {
        guard let activity = activeActivity(sessionID: sessionID) else { return }
        let old = activity.content.state
        guard old.source != "app" || appIsForeground,
              ["listening", "searching"].contains(old.phase) else { return }
        let state = RecztRecognitionAttributes.ContentState(
            phase: phase, title: title ?? old.title, artist: artist ?? old.artist,
            secondsRemaining: secondsRemaining ?? old.secondsRemaining,
            source: source ?? old.source,
            listeningEndsAt: phase == "listening"
                ? (old.listeningEndsAt ?? Date().addingTimeInterval(Double(max(0, secondsRemaining ?? old.secondsRemaining)))) : nil,
            language: old.language ?? RecztSharedStore.shared.recognitionSettings().language)
        await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(60)))
    }

    func showResult(title: String, artist: String, source: String? = nil,
                    redirecting: Bool = false, sessionID: String? = nil) async {
        guard let activity = activeActivity(sessionID: sessionID) else { return }
        let old = activity.content.state
        guard old.source != "app" || appIsForeground else { return }
        let state = RecztRecognitionAttributes.ContentState(
            phase: "found", title: title, artist: artist, secondsRemaining: 0,
            source: source ?? old.source,
            language: old.language ?? RecztSharedStore.shared.recognitionSettings().language,
            redirecting: redirecting)
        await publishResult(state, activity: activity)
    }

    func finish(phase: String, message: String? = nil, sessionID: String? = nil) async {
        guard let activity = activeActivity(sessionID: sessionID) else { return }
        if ["found", "noMatch", "error", "denied"].contains(activity.content.state.phase) &&
            !["cancelled", "idle"].contains(phase) { return }
        if ["noMatch", "error", "denied"].contains(phase) &&
            (activity.content.state.source != "app" || appIsForeground) {
            var state = activity.content.state
            state.phase = phase
            state.title = "Reczt"
            state.artist = ""
            state.secondsRemaining = 0
            state.listeningEndsAt = nil
            await publishResult(state, activity: activity)
        } else {
            await dismiss(sessionID: activity.attributes.sessionID)
        }
    }

    private func publishResult(_ state: RecztRecognitionAttributes.ContentState,
                               activity: Activity<RecztRecognitionAttributes>) async {
        let language = state.language ?? "en"
        let titleKey = state.phase == "found" ? "activity_found" :
            state.phase == "noMatch" ? "activity_no_match" :
            state.phase == "denied" ? "mic_denied" : "activity_error"
        let hintKey = state.phase == "found" ?
            (state.redirecting == true ? "activity_redirecting" : "activity_found_hint") : "activity_no_match_hint"
        let headline = RecztRecognitionAttributes.localizedText(titleKey, language: language)
        let hint = RecztRecognitionAttributes.localizedText(hintKey, language: language)
        // Alerting updates ask iOS to surface the result. Expansion is an iOS decision.
        await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(3)),
            alertConfiguration: AlertConfiguration(
                title: LocalizedStringResource(stringLiteral: headline),
                body: LocalizedStringResource(stringLiteral: hint), sound: .default))
        if state.source != "app" {
            // An App Intent may be suspended as soon as it returns. End in
            // that same task instead of depending on a later sleeping task.
            await activity.end(ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(3)))
            if currentSessionID == activity.attributes.sessionID { currentSessionID = nil }
            return
        }
        guard currentSessionID == activity.attributes.sessionID,
              activity.activityState == .active || activity.activityState == .stale else { return }
        dismissalTask?.cancel()
        let id = activity.attributes.sessionID
        dismissalTask = Task {
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            await self.dismiss(sessionID: id)
        }
    }

    func setAppForeground(_ foreground: Bool) async {
        if appIsForeground != foreground { lifecycleRevision += 1 }
        appIsForeground = foreground
        guard !foreground else { return }
        for activity in Activity<RecztRecognitionAttributes>.activities
            where activity.content.state.source == "app" {
            await dismiss(sessionID: activity.attributes.sessionID)
        }
    }

    func clearOrphanedAppActivities() async {
        guard currentSessionID == nil else { return }
        for activity in Activity<RecztRecognitionAttributes>.activities
            where activity.content.state.source == "app" {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func refreshLanguage(_ language: String) async {
        for activity in Activity<RecztRecognitionAttributes>.activities {
            guard activity.activityState == .active || activity.activityState == .stale else { continue }
            var state = activity.content.state
            state.language = language
            await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
        }
    }

    private func dismiss(sessionID: String) async {
        guard let activity = Activity<RecztRecognitionAttributes>.activities.first(where: {
            $0.attributes.sessionID == sessionID
        }) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        if currentSessionID == sessionID { currentSessionID = nil }
    }

    private func activeActivity(sessionID: String? = nil) -> Activity<RecztRecognitionAttributes>? {
        let activities = Activity<RecztRecognitionAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
        if let id = sessionID ?? currentSessionID {
            return activities.first(where: { $0.attributes.sessionID == id })
        }
        return sessionID == nil ? activities.first : nil
    }
}
