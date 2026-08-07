import UIKit
import Flutter
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, launchOptions: launchOptions)
  }
}

@available(iOS 16.0, *)
struct FindSongIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Song"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 16.0, *)
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        //  Notice: NO square brackets [ ] around AppShortcut(...)
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
    }
}