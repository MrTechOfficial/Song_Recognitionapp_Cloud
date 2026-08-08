import UIKit
import Flutter
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var siriChannel: FlutterMethodChannel?
  private var launchedFromSiri = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    siriChannel = FlutterMethodChannel(
      name: "com.handsfreefinder/siri",
      binaryMessenger: controller.binaryMessenger
    )

    siriChannel?.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "checkSiriTrigger" {
        result(self.launchedFromSiri)
        self.launchedFromSiri = false
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

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