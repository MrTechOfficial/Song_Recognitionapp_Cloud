import UIKit
import Flutter

class SceneDelegate: FlutterSceneDelegate {

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        // 1. Check if opened via URL (handsfreefinder://siri)
        if let url = connectionOptions.urlContexts.first?.url {
            if url.scheme == "handsfreefinder" || url.absoluteString.contains("siri") {
                UserDefaults.standard.set(true, forKey: "launchedFromSiri")
            }
        }
        
        // 2. Check if opened via Siri User Activity
        if let userActivity = connectionOptions.userActivities.first {
            if userActivity.activityType.contains("IdentifySongIntent") || userActivity.activityType.contains("siri") {
                UserDefaults.standard.set(true, forKey: "launchedFromSiri")
            }
        }
    }

    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        super.scene(scene, openURLContexts: URLContexts)
        
        if let url = URLContexts.first?.url {
            if url.scheme == "handsfreefinder" || url.absoluteString.contains("siri") {
                UserDefaults.standard.set(true, forKey: "launchedFromSiri")
            }
        }
    }
}