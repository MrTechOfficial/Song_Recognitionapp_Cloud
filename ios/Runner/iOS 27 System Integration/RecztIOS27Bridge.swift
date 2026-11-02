import Flutter
import Foundation
import UIKit

final class RecztIOS27Bridge {
    private static var lifecycleObservers: [NSObjectProtocol] = []
    private static var channel: FlutterMethodChannel?

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "reczt/ios27",
            binaryMessenger: messenger
        )
        self.channel = channel
        Task { await RecztLiveActivityManager.shared.clearOrphanedAppActivities() }
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        lifecycleObservers = [
            NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
                Task { await RecztLiveActivityManager.shared.setAppForeground(false) }
            },
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                Task { await RecztLiveActivityManager.shared.setAppForeground(true) }
            },
            NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                Task { await RecztLiveActivityManager.shared.setAppForeground(false) }
            }
        ]

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "startRecognitionActivity":
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "BAD_ARGUMENTS", message: "Missing Live Activity arguments.", details: nil))
                    return
                }
                let duration = (args["durationSeconds"] as? NSNumber)?.intValue ?? 8
                let environment = (args["environment"] as? String) ?? "quiet"
                let source = (args["source"] as? String) ?? "app"
                let seasonalTheme = args["seasonalTheme"] as? String
                Task {
                    do {
                        let id = try await RecztLiveActivityManager.shared.start(
                            durationSeconds: duration,
                            environment: environment,
                            source: source,
                            seasonalTheme: seasonalTheme
                        )
                        await returnToFlutter(result, id)
                    } catch {
                        await returnFlutterError(result, code: "LIVE_ACTIVITY_START", error: error)
                    }
                }

            case "updateRecognitionActivity":
                guard let args = call.arguments as? [String: Any] else {
                    result(nil)
                    return
                }
                let phase = (args["phase"] as? String) ?? "listening"
                let remaining = (args["secondsRemaining"] as? NSNumber)?.intValue
                guard let sessionID = args["sessionID"] as? String else { result(nil); return }
                Task {
                    await RecztLiveActivityManager.shared.update(
                        phase: phase,
                        secondsRemaining: remaining, sessionID: sessionID
                    )
                    await returnToFlutter(result, nil)
                }

            case "showRecognitionResult":
                guard let args = call.arguments as? [String: Any] else {
                    result(nil)
                    return
                }
                guard let sessionID = args["sessionID"] as? String else { result(nil); return }
                let redirecting = (args["redirecting"] as? Bool) ?? false
                let title = (args["title"] as? String) ?? "Reczt"
                let artist = (args["artist"] as? String) ?? ""
                Task {
                    await RecztLiveActivityManager.shared.showResult(
                        title: title,
                        artist: artist, redirecting: redirecting, sessionID: sessionID
                    )
                    await returnToFlutter(result, nil)
                }

            case "endRecognitionActivity":
                let args = call.arguments as? [String: Any]
                let phase = (args?["phase"] as? String) ?? "idle"
                guard let sessionID = args?["sessionID"] as? String else { result(nil); return }
                Task {
                    await RecztLiveActivityManager.shared.finish(
                        phase: phase,
                        message: nil, sessionID: sessionID
                    )
                    await returnToFlutter(result, nil)
                }

            case "syncRecognitionSettings":
                guard let args = call.arguments as? [String: Any] else {
                    result(nil)
                    return
                }
                var settings = RecztSharedStore.shared.recognitionSettings()
                if let language = args["language"] as? String { settings.language = language }
                if let environment = args["environment"] as? String { settings.environment = environment }
                if let theme = args["seasonalTheme"] as? String { settings.seasonalTheme = theme }
                if let duration = (args["durationSeconds"] as? NSNumber)?.intValue {
                    settings.durationSeconds = duration
                }
                if let backend = args["backendUrl"] as? String, !backend.isEmpty {
                    settings.backendURL = backend
                }
                RecztSharedStore.shared.saveRecognitionSettings(settings)
                let language = settings.language
                Task {
                    await RecztLiveActivityManager.shared.refreshLanguage(language)
                    await returnToFlutter(result, nil)
                }

            case "dismissAppRecognitionActivities":
                Task {
                    await RecztLiveActivityManager.shared.setAppForeground(false)
                    await returnToFlutter(result, nil)
                }

            case "resumeAppRecognitionActivities":
                Task {
                    await RecztLiveActivityManager.shared.setAppForeground(true)
                    await returnToFlutter(result, nil)
                }

            case "syncSongHistory":
                guard let args = call.arguments as? [String: Any],
                      let history = args["history"] as? [String] else {
                    result(nil)
                    return
                }
                let songs = RecztSharedStore.shared.syncHistoryFromFlutter(history)
                if #available(iOS 27.0, *) {
                    Task {
                        try? await RecztEntityIndexer.refresh(songs: songs)
                    }
                }
                result(nil)

            case "drainExternalRecognitions":
                let values = RecztSharedStore.shared
                    .drainRecognitionResults()
                    .map(\.flutterDictionary)
                result(values)

            case "analyzeMusicPreview":
                guard let args = call.arguments as? [String: Any],
                      let rawURL = args["previewUrl"] as? String,
                      let url = URL(string: rawURL) else {
                    result(FlutterError(code: "BAD_PREVIEW_URL", message: "Missing music preview URL.", details: nil))
                    return
                }
                Task {
                    do {
                        let summary = try await RecztMusicUnderstandingService.shared.analyzePreview(at: url)
                        await returnToFlutter(result, summary)
                    } catch {
                        await returnFlutterError(result, code: "MUSIC_UNDERSTANDING", error: error)
                    }
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    @MainActor
    private static func returnToFlutter(_ result: @escaping FlutterResult, _ value: Any?) {
        result(value)
    }

    @MainActor
    private static func returnFlutterError(
        _ result: @escaping FlutterResult,
        code: String,
        error: Error
    ) {
        result(
            FlutterError(
                code: code,
                message: error.localizedDescription,
                details: nil
            )
        )
    }
}
