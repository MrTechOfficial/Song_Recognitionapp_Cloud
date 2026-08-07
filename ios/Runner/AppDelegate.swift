import UIKit
import Flutter
import AppIntents

@available(iOS 16.0, *)
struct FindSongIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Song"
    static var description = IntentDescription("Opens Reczt and starts recognizing audio.")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let controller = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "com.handsfreefinder/siri", binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("onSiriTrigger", arguments: nil)
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: FindSongIntent(),
                phrases: [
                    "Find song in \(.applicationName)",
                    "Find song with \(.applicationName)",
                    "Find song"
                ],
                shortTitle: "Find Song",
                systemImageName: "music.note"
            )
        ]
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}