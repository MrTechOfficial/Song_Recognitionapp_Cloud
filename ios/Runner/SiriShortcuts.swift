import AppIntents
import UIKit

// 1. Define the Intent action that launches Reczt
@available(iOS 16.0, *)
struct IdentifySongIntent: AppIntent {
    static let title: LocalizedStringResource = "Identify Song with Reczt"
    static let openAppWhenRun: Bool = true // Forces iOS to bring Reczt to the foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        // Set the flag in UserDefaults so Flutter knows Siri launched it
        UserDefaults.standard.set(true, forKey: "launchedFromSiri")
        
        // Notify Flutter via Method Channel if already open in background
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let controller = scene.windows.first?.rootViewController as? FlutterViewController {
            let siriChannel = FlutterMethodChannel(name: "com.handsfreefinder/siri", binaryMessenger: controller.binaryMessenger)
            siriChannel.invokeMethod("onSiriTrigger", arguments: nil)
        }
        
        return .result()
    }
}

// 2. Register spoken phrases that iOS registers automatically on install
@available(iOS 16.0, *)
struct RecztShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: IdentifySongIntent(),
            phrases: [
                "Activate \(.applicationName)",
                "Identify song with \(.applicationName)",
                "Song search with \(.applicationName)"
            ],
            shortTitle: "Identify Song",
            systemImageName: "waveform"
        )
    }
}