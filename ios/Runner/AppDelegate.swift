import UIKit
import Flutter
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate {
  static var siriChannel: FlutterMethodChannel?
  static var siriTriggeredOnLaunch = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.example.songrecognition/siri",
        binaryMessenger: controller.binaryMessenger
      )
      AppDelegate.siriChannel = channel

      channel.setMethodCallHandler { (call, result) in
        if call.method == "checkSiriTrigger" {
          result(AppDelegate.siriTriggeredOnLaunch)
          AppDelegate.siriTriggeredOnLaunch = false
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  static func triggerSiriRecord() {
    siriTriggeredOnLaunch = true
    siriChannel?.invokeMethod("triggerSiriRecord", arguments: nil)
  }
}

@available(iOS 16.0, *)
struct FindSongIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Song"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDelegate.triggerSiriRecord()
        return .result()
    }
}

@available(iOS 16.0, *)
struct AppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindSongIntent(),
            phrases: [
                "Find song in \(.applicationName)",
                "Find song with \(.applicationName)",
                "Open \(.applicationName) to find song"
            ],
            shortTitle: "Find Song",
            systemImageName: "music.note"
        )
    }
}