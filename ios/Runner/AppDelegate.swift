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

        // 3. Send real-time signal for Warm Start (if Flutter is already open)
        channel?.invokeMethod("startSiriRecognition", arguments: nil)
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
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
}

class SceneDelegate: FlutterSceneDelegate {

    // 1. Cold Start
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        
        if let url = connectionOptions.urlContexts.first?.url {
            if url.scheme == "handsfreefinder" || url.absoluteString.contains("siri") {
                SiriBridge.sendSiriSignal()
            }
        }
    }

    // 2. Warm Start (App in background)
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        super.scene(scene, openURLContexts: URLContexts)
        if let url = URLContexts.first?.url {
            if url.scheme == "handsfreefinder" || url.absoluteString.contains("siri") {
                SiriBridge.sendSiriSignal()
            }
        }
    }

    // 3. Siri User Activity / Shortcut Intent
    override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        super.scene(scene, continue: userActivity)
        if userActivity.activityType.contains("IdentifySongIntent") || userActivity.activityType.contains("siri") {
            SiriBridge.sendSiriSignal()
        }
    }
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