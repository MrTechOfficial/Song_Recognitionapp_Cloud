import UIKit
import Flutter
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var siriChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        if let controller = window?.rootViewController as? FlutterViewController {
            siriChannel = FlutterMethodChannel(
                name: "com.example.song_recognition/siri",
                binaryMessenger: controller.binaryMessenger
            )
            
            siriChannel?.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) in
                if call.method == "checkSiriTrigger" {
                    // Check persistent storage for Siri flag
                    let triggered = UserDefaults.standard.bool(forKey: "launchedFromSiri")
                    if triggered {
                        UserDefaults.standard.set(false, forKey: "launchedFromSiri") // Reset flag
                    }
                    result(triggered)
                } else {
                    result(FlutterMethodNotImplemented)
                }
            })
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        if url.scheme == "handsfreefinder" || url.absoluteString.contains("siri") {
            UserDefaults.standard.set(true, forKey: "launchedFromSiri")
            siriChannel?.invokeMethod("onSiriTrigger", arguments: nil)
        }
        return super.application(app, open: url, options: options)
    }
}

// MARK: - Siri App Shortcuts (iOS 16+)

@available(iOS 16.0, *)
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: IdentifySongIntent(),
                phrases: [
                    "Activate \(.applicationName)",
                    "Find Song With \(.applicationName)"
                ],
                shortTitle: "Identify Song",
                systemImageName: "waveform"
            )
        ]
    }
}

@available(iOS 16.0, *)
struct IdentifySongIntent: AppIntent {
    static var title: LocalizedStringResource = "Identify Song"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Persist flag directly to UserDefaults
        UserDefaults.standard.set(true, forKey: "launchedFromSiri")
        return .result()
    }
}