import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var siriChannel: FlutterMethodChannel?
  private var launchedFromSiri = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    siriChannel = FlutterMethodChannel(name: "com.handsfreefinder/siri",
                                              binaryMessenger: controller.binaryMessenger)

    siriChannel?.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "checkSiriTrigger" {
        result(self.launchedFromSiri)
        self.launchedFromSiri = false // Reset after reading
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle URL launches from Siri Shortcuts
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