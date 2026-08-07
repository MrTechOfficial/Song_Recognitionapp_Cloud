import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.handsfreefinder/siri"
  private var initialUrl: String?
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    // Check if launched cold via Siri deep link
    methodChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getInitialUrl" {
        result(self?.initialUrl)
        self?.initialUrl = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    if let url = launchOptions?[.url] as? URL {
      initialUrl = url.absoluteString
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Captures Siri opening the app while it's in the background (Warm Launch)
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    methodChannel?.invokeMethod("onSiriTrigger", arguments: url.absoluteString)
    return true
  }
}
import UIKit
import Flutter
import AppIntents

// 1. Define the Intent Action
@available(iOS 16.0, *)
struct FindSongIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Song"
    static var description = IntentDescription("Opens Reczt and starts recognizing audio.")

    // Open app when triggered by Siri
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Send deep link signal to Flutter UI
        if let controller = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "com.handsfreefinder/siri", binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("onSiriTrigger", arguments: nil)
        }
        return .result()
    }
}

// 2. Register Auto-Shortcuts (Runs the moment the app is downloaded!)
@available(iOS 16.0, *)
struct AppShortcuts: AppShortcutProvider {
    static var appShortcuts: [AppShortcut] {
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