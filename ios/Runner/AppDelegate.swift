import UIKit
import Flutter
import AppIntents
import AVFoundation

// Helper to bridge Siri events to Flutter
class SiriBridge {
    static var channel: FlutterMethodChannel?

    static func sendSiriSignal() {
        // 1. Set flag for Cold Start (Flutter's shared_preferences expects the "flutter." prefix)
        UserDefaults.standard.set(true, forKey: "flutter.launchedFromSiri")

        // 2. Configure Audio Session immediately so Siri releases mic control
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        // 3. Send real-time signal for Warm Start safely on the main thread
        DispatchQueue.main.async {
            channel?.invokeMethod("startSiriRecognition", arguments: nil)
        }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        // Initialize MethodChannel (matching main.dart: com.handsfreefinder/siri)
        let channel = FlutterMethodChannel(
            name: "com.handsfreefinder/siri", 
            binaryMessenger: controller.binaryMessenger
        )
        SiriBridge.channel = channel

        // Handle incoming calls from Flutter (e.g. checkSiriTrigger)
        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "checkSiriTrigger" {
                let launchedFromSiri = UserDefaults.standard.bool(forKey: "flutter.launchedFromSiri")
                if launchedFromSiri {
                    // Reset flag immediately
                    UserDefaults.standard.set(false, forKey: "flutter.launchedFromSiri")
                    result(true)
                } else {
                    result(false)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}

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
        SiriBridge.sendSiriSignal()
        return .result()
    }
}