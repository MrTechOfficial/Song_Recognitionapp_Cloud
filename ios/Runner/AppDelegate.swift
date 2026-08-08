import UIKit
import Flutter
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    // Properties for handling Siri triggers and communication with Flutter
    private var siriChannel: FlutterMethodChannel?
    private var launchedFromSiri: Bool = false

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)
        
        // Setup Method Channel for Siri communication with Dart
        if let controller = window?.rootViewController as? FlutterViewController {
            siriChannel = FlutterMethodChannel(
                name: "com.handsfreefinder/siri", // Adjust channel name if your Dart code uses a specific one
                binaryMessenger: controller.binaryMessenger
            )
            
            siriChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
                if call.method == "checkSiriTrigger" {
                    result(self?.launchedFromSiri ?? false)
                    self?.launchedFromSiri = false // Reset after reading
                } else {
                    result(FlutterMethodNotImplemented)
                }
            })
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // URL Scheme Handler for Siri / Custom Schemes
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        if url.scheme == "handsfreefinder" || url.absoluteString.contains("siri") {
            launchedFromSiri = true
            siriChannel?.invokeMethod("onSiriTrigger", arguments: nil)
        }
        return super.application(app, open: url, options: options)
    }

    static func triggerSiriRecord() {
        // Siri trigger logic if invoked statically
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
        return .result()
    }
}