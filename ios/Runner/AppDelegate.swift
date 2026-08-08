import UIKit
import Flutter
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    // Shared flag accessible by AppIntent
    static var launchedFromSiri: Bool = false
    private var siriChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        if let controller = window?.rootViewController as? FlutterViewController {
            siriChannel = FlutterMethodChannel(
                name: "com.example.song_recognition/siri", // Check that this matches main.dart!
                binaryMessenger: controller.binaryMessenger
            )
            
            siriChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
                if call.method == "checkSiriTrigger" {
                    result(AppDelegate.launchedFromSiri)
                    AppDelegate.launchedFromSiri = false // Reset flag after reading
                } else {
                    result(FlutterMethodNotImplemented)
                }
            })
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // URL Scheme Handler (e.g. handsfreefinder://siri)
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        if url.scheme == "handsfreefinder" || url.absoluteString.contains("siri") {
            AppDelegate.launchedFromSiri = true
            siriChannel?.invokeMethod("onSiriTrigger", arguments: nil)
        }
        return super.application(app, open: url, options: options)
    }

    static func triggerSiriRecord() {
        AppDelegate.launchedFromSiri = true
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
        // Set flag so Flutter knows Siri opened the app
        AppDelegate.launchedFromSiri = true
        return .result()
    }
}