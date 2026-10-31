import ActivityKit
import Foundation

@available(iOS 17.0, *)
struct RecztRecognitionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var title: String
        var artist: String
        var secondsRemaining: Int
        var source: String

        static func listening(secondsRemaining: Int, source: String) -> Self {
            .init(
                phase: "listening",
                title: "Listening…",
                artist: "Sing or hum a song",
                secondsRemaining: secondsRemaining,
                source: source
            )
        }
    }

    var sessionID: String
    var startedAt: Date
    var environment: String
    // Optional so activities created before seasonal styling still decode.
    var seasonalTheme: String? = nil

    var isChristmas: Bool { seasonalTheme == "christmas" }
    var isHalloween: Bool { seasonalTheme == "halloween" }
}
