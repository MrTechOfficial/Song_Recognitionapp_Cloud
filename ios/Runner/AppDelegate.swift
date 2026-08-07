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