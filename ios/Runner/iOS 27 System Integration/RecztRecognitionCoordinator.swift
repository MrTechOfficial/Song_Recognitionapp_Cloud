import AVFAudio
import Foundation

struct RecztRecognitionError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}

struct RecztNativeCandidate: Sendable {
    var title: String
    var artist: String
    var confidence: Double
    var rankingScore: Double?
    var genre: String?
    var emotion: String?
    var spotifyURL: String?
    var appleMusicURL: String?
    var coverURL: String?

    var effectiveScore: Double { rankingScore ?? confidence }
}

actor RecztRecognitionCoordinator {
    static let shared = RecztRecognitionCoordinator()

    private var recorder: AVAudioRecorder?
    private var currentRecordingURL: URL?

    func cancel() async {
        recorder?.stop()
        recorder = nil
        if let currentRecordingURL {
            try? FileManager.default.removeItem(at: currentRecordingURL)
        }
        currentRecordingURL = nil
        await RecztLiveActivityManager.shared.finish(
            phase: "cancelled",
            message: "Recognition cancelled"
        )
    }

    func recognize(
        source: String,
        progress: (@Sendable (Int, Int, String) -> Void)? = nil
    ) async throws -> RecztRecognitionResult {
        let settings = RecztSharedStore.shared.recognitionSettings()
        let duration = max(4, min(settings.durationSeconds, 20))

        guard await AVAudioApplication.requestRecordPermission() else {
            await RecztLiveActivityManager.shared.finish(
                phase: "denied",
                message: "Microphone permission is required"
            )
            throw RecztRecognitionError(message: "Reczt needs microphone permission to identify a song.")
        }

        // AudioRecordingIntent requires a Live Activity while the microphone is active.
        _ = try await RecztLiveActivityManager.shared.start(
            durationSeconds: duration,
            environment: settings.environment,
            source: source
        )

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reczt-intent-\(UUID().uuidString).wav")
        currentRecordingURL = url

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: audioSettings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw RecztRecognitionError(message: "Reczt couldn't start the microphone.")
        }
        self.recorder = recorder

        do {
            for elapsed in 0..<duration {
                try Task.checkCancellation()
                let remaining = duration - elapsed
                progress?(elapsed, duration, "Listening")
                await RecztLiveActivityManager.shared.update(
                    phase: "listening",
                    secondsRemaining: remaining,
                    title: "Listening…",
                    artist: "Sing or hum a song",
                    source: source
                )
                try await Task.sleep(for: .seconds(1))
            }

            recorder.stop()
            self.recorder = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)

            progress?(duration, duration + 3, "Searching")
            await RecztLiveActivityManager.shared.update(
                phase: "searching",
                secondsRemaining: 0,
                title: "Searching…",
                artist: "Matching your song",
                source: source
            )

            let candidates = try await uploadAndParse(
                fileURL: url,
                settings: settings
            )
            try? FileManager.default.removeItem(at: url)
            currentRecordingURL = nil

            guard isSafeBackgroundMatch(candidates, environment: settings.environment),
                  let top = candidates.first else {
                await RecztLiveActivityManager.shared.finish(
                    phase: "noMatch",
                    message: "Try singing a little longer"
                )
                throw RecztRecognitionError(message: "I couldn't identify that song.")
            }

            let result = RecztRecognitionResult(
                title: top.title,
                artist: top.artist,
                confidence: top.effectiveScore,
                source: source,
                environment: settings.environment,
                albumCover: top.coverURL,
                genre: top.genre,
                emotion: top.emotion,
                spotifyURL: top.spotifyURL,
                appleMusicURL: top.appleMusicURL
            )
            RecztSharedStore.shared.appendRecognitionResult(result)
            await RecztLiveActivityManager.shared.showResult(
                title: result.title,
                artist: result.artist,
                source: source
            )
            progress?(duration + 3, duration + 3, "Found")
            return result
        } catch {
            recorder.stop()
            self.recorder = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            if currentRecordingURL != nil {
                try? FileManager.default.removeItem(at: url)
                currentRecordingURL = nil
            }
            if error is CancellationError {
                await RecztLiveActivityManager.shared.finish(
                    phase: "cancelled",
                    message: "Recognition cancelled"
                )
            }
            throw error
        }
    }

    private func uploadAndParse(
        fileURL: URL,
        settings: RecztRecognitionSettings
    ) async throws -> [RecztNativeCandidate] {
        guard let endpoint = URL(string: settings.backendURL) else {
            throw RecztRecognitionError(message: "Recognition service URL is invalid.")
        }

        let boundary = "RecztBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ string: String) {
            body.append(string.data(using: .utf8)!)
        }
        let fields = [
            "language": settings.language,
            "vocal_isolation": "true",
            "environment": settings.environment,
            "auto_play": "false",
            "background_queue": "false",
        ]
        for (key, value) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"reczt_intent.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(try Data(contentsOf: fileURL))
        append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw RecztRecognitionError(message: "The recognition service didn't respond successfully.")
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RecztRecognitionError(message: "Reczt received an invalid recognition response.")
        }

        let items = extractRecognitionResults(root)
        return items
            .map(candidate(from:))
            .filter { !$0.title.isEmpty }
            .sorted { $0.effectiveScore > $1.effectiveScore }
    }

    private func extractRecognitionResults(_ root: [String: Any]) -> [[String: Any]] {
        if let results = root["results"] as? [[String: Any]], !results.isEmpty {
            return results
        }
        if let metadata = root["metadata"] as? [String: Any] {
            if let humming = metadata["humming"] as? [[String: Any]], !humming.isEmpty {
                return humming
            }
            if let music = metadata["music"] as? [[String: Any]], !music.isEmpty {
                return music
            }
        }
        if let humming = root["humming"] as? [[String: Any]], !humming.isEmpty {
            return humming
        }
        return [root]
    }

    private func candidate(from item: [String: Any]) -> RecztNativeCandidate {
        let title = string(item["title"] ?? item["name"])
        var artist = string(item["artist"])
        if artist.isEmpty, let artists = item["artists"] as? [Any], let first = artists.first {
            if let object = first as? [String: Any] {
                artist = string(object["name"])
            } else {
                artist = string(first)
            }
        }
        if artist.isEmpty { artist = "Unknown Artist" }

        let scoreKeys = [
            "confidence", "score", "humming_score", "hummingScore",
            "match_score", "confidence_score", "matchConfidence",
            "acrcloud_score", "similarity"
        ]
        let rankKeys = ["selection_score", "ranking_score"]
        let confidence = normalizedScore(firstNumber(in: item, keys: scoreKeys)) ?? 0
        let rankingScore = normalizedScore(firstNumber(in: item, keys: rankKeys))

        var spotifyURL = stringOptional(item["spotify_url"])
        var appleMusicURL = stringOptional(item["apple_music_url"])
        if let external = item["external_metadata"] as? [String: Any] {
            if spotifyURL == nil, let spotify = external["spotify"] as? [String: Any] {
                if let track = spotify["track"] as? [String: Any], let id = stringOptional(track["id"]) {
                    spotifyURL = "https://open.spotify.com/track/\(id)"
                } else if let id = stringOptional(spotify["id"]) {
                    spotifyURL = "https://open.spotify.com/track/\(id)"
                }
            }
            if appleMusicURL == nil, let apple = external["apple_music"] as? [String: Any] {
                appleMusicURL = stringOptional(apple["url"] ?? apple["link"])
            }
        }

        return RecztNativeCandidate(
            title: title,
            artist: artist,
            confidence: confidence,
            rankingScore: rankingScore,
            genre: stringOptional(item["genre"]),
            emotion: stringOptional(item["emotion"]),
            spotifyURL: spotifyURL,
            appleMusicURL: appleMusicURL,
            coverURL: stringOptional(item["cover_url"] ?? item["album_art"] ?? item["artwork_url"])
        )
    }

    private func isSafeBackgroundMatch(
        _ candidates: [RecztNativeCandidate],
        environment: String
    ) -> Bool {
        guard let top = candidates.first else { return false }
        let minimumScore: Double
        switch environment.lowercased() {
        case "loud": minimumScore = 0.56
        case "outdoors": minimumScore = 0.58
        default: minimumScore = 0.52
        }

        guard top.confidence >= 0.46, top.effectiveScore >= minimumScore else { return false }
        if top.artist.caseInsensitiveCompare("Unknown Artist") == .orderedSame,
           top.effectiveScore < 0.72 {
            return false
        }
        if candidates.count > 1 {
            let second = candidates[1].effectiveScore
            let gap = top.effectiveScore - second
            if second >= 0.30, top.effectiveScore < 0.82, gap < 0.10 {
                return false
            }
        }
        return true
    }

    private func normalizedScore(_ value: Double?) -> Double? {
        guard var value else { return nil }
        if value > 1 { value /= 100 }
        return min(max(value, 0), 1)
    }

    private func firstNumber(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let number = object[key] as? NSNumber { return number.doubleValue }
            if let text = object[key] as? String, let number = Double(text) { return number }
        }
        return nil
    }

    private func string(_ value: Any?) -> String {
        stringOptional(value) ?? ""
    }

    private func stringOptional(_ value: Any?) -> String? {
        guard let value else { return nil }
        let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
