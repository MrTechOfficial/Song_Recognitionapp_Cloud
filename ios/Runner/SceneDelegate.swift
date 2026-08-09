import UIKit
import Flutter

import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

    // 1. Cold Start
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        
        if let url = connectionOptions.urlContexts.first?.url {
            if url.scheme == "handsfreefinder" || url.absoluteString.contains("siri") {
                UserDefaults.standard.set(true, forKey: "launchedFromSiri")
            }
        }
    }

    // 2. Warm Start (App already in background when Siri opens URL)
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        super.scene(scene, openURLContexts: URLContexts)
        if let url = URLContexts.first?.url {
            if url.scheme == "handsfreefinder" || url.absoluteString.contains("siri") {
                UserDefaults.standard.set(true, forKey: "launchedFromSiri")
            }
        }
    }

    // 3. Siri User Activity / Shortcut Intent
    override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        super.scene(scene, continue: userActivity)
        if userActivity.activityType.contains("IdentifySongIntent") || userActivity.activityType.contains("siri") {
            UserDefaults.standard.set(true, forKey: "launchedFromSiri")
        }
    }
}