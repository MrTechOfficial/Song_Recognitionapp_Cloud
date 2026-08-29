import UIKit
import Flutter
import AppIntents
import AVFoundation

// Helper to bridge Siri events to Flutter.
class SiriBridge {
    static var channel: FlutterMethodChannel?

    static func sendSiriSignal() {
        // shared_preferences stores native keys with the "flutter." prefix.
        UserDefaults.standard.set(true, forKey: "flutter.launchedFromSiri")

        // Configure the audio session so Siri releases microphone control.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        // Warm-start signal to Flutter.
        DispatchQueue.main.async {
            SiriBridge.channel?.invokeMethod(
                "startSiriRecognition",
                arguments: nil
            )
        }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController

        let siriChannel = FlutterMethodChannel(
            name: "com.handsfreefinder/siri",
            binaryMessenger: controller.binaryMessenger
        )

        SiriBridge.channel = siriChannel

        siriChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "checkSiriTrigger":
                let launchedFromSiri = UserDefaults.standard.bool(
                    forKey: "flutter.launchedFromSiri"
                )

                if launchedFromSiri {
                    UserDefaults.standard.set(
                        false,
                        forKey: "flutter.launchedFromSiri"
                    )
                }

                result(launchedFromSiri)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)

        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }
}

@available(iOS 16.0, *)
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
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
