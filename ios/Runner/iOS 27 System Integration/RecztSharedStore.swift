import Foundation

// Add this same App Group capability to the Runner and the Widget/Control target.
// If you choose a different identifier, change it here in one place.
enum RecztSharedConstants {
    static let appGroupID = "group.com.lesliekanebazos.reczt.shared"
    static let settingsKey = "reczt.ios27.settings.v1"
    static let historyKey = "reczt.ios27.history.v1"
    static let pendingResultsKey = "reczt.ios27.pendingResults.v1"
}

struct RecztRecognitionSettings: Codable, Sendable {
    var language: String = "en"
    var environment: String = "quiet"
    var durationSeconds: Int = 8
    var backendURL: String = "https://song-recognitionapp-cloud.onrender.com/recognize"
}

struct RecztHistorySong: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var artist: String
    var albumCover: String?
    var genre: String?
    var emotion: String?
    var spotifyURL: String?
    var appleMusicURL: String?

    init(
        id: String? = nil,
        title: String,
        artist: String,
        albumCover: String? = nil,
        genre: String? = nil,
        emotion: String? = nil,
        spotifyURL: String? = nil,
        appleMusicURL: String? = nil
    ) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id ?? Self.stableID(title: self.title, artist: self.artist)
        self.albumCover = albumCover
        self.genre = genre
        self.emotion = emotion
        self.spotifyURL = spotifyURL
        self.appleMusicURL = appleMusicURL
    }

    static func stableID(title: String, artist: String) -> String {
        func normalize(_ value: String) -> String {
            value
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
        }
        return "\(normalize(title))|\(normalize(artist))"
    }
}

struct RecztRecognitionResult: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var artist: String
    var confidence: Double?
    var recognizedAt: Date
    var source: String
    var environment: String
    var albumCover: String?
    var genre: String?
    var emotion: String?
    var spotifyURL: String?
    var appleMusicURL: String?
    var previewURL: String?

    init(
        id: String = UUID().uuidString.lowercased(),
        title: String,
        artist: String,
        confidence: Double? = nil,
        recognizedAt: Date = Date(),
        source: String,
        environment: String,
        albumCover: String? = nil,
        genre: String? = nil,
        emotion: String? = nil,
        spotifyURL: String? = nil,
        appleMusicURL: String? = nil,
        previewURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.confidence = confidence
        self.recognizedAt = recognizedAt
        self.source = source
        self.environment = environment
        self.albumCover = albumCover
        self.genre = genre
        self.emotion = emotion
        self.spotifyURL = spotifyURL
        self.appleMusicURL = appleMusicURL
        self.previewURL = previewURL
    }

    var flutterDictionary: [String: Any] {
        var value: [String: Any] = [
            "id": id,
            "title": title,
            "artist": artist,
            "recognizedAt": ISO8601DateFormatter().string(from: recognizedAt),
            "source": source,
            "environment": environment,
        ]
        if let confidence { value["confidence"] = confidence }
        if let albumCover { value["albumCover"] = albumCover }
        if let genre { value["genre"] = genre }
        if let emotion { value["emotion"] = emotion }
        if let spotifyURL { value["spotifyUrl"] = spotifyURL }
        if let appleMusicURL { value["appleMusicUrl"] = appleMusicURL }
        if let previewURL { value["previewUrl"] = previewURL }
        return value
    }
}

final class RecztSharedStore: @unchecked Sendable {
    static let shared = RecztSharedStore()

    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: RecztSharedConstants.appGroupID) ?? .standard
    }

    func recognitionSettings() -> RecztRecognitionSettings {
        lock.withLock {
            guard let data = defaults.data(forKey: RecztSharedConstants.settingsKey),
                  let value = try? decoder.decode(RecztRecognitionSettings.self, from: data) else {
                return RecztRecognitionSettings()
            }
            return value
        }
    }

    func saveRecognitionSettings(_ settings: RecztRecognitionSettings) {
        lock.withLock {
            guard let data = try? encoder.encode(settings) else { return }
            defaults.set(data, forKey: RecztSharedConstants.settingsKey)
        }
    }

    func history() -> [RecztHistorySong] {
        lock.withLock {
            guard let data = defaults.data(forKey: RecztSharedConstants.historyKey),
                  let value = try? decoder.decode([RecztHistorySong].self, from: data) else {
                return []
            }
            return value
        }
    }

    func replaceHistory(_ songs: [RecztHistorySong]) {
        let deduped = songs.reduce(into: [RecztHistorySong]()) { result, song in
            if !result.contains(where: { $0.id == song.id }) {
                result.append(song)
            }
        }
        lock.withLock {
            guard let data = try? encoder.encode(Array(deduped.prefix(100))) else { return }
            defaults.set(data, forKey: RecztSharedConstants.historyKey)
        }
    }

    func syncHistoryFromFlutter(_ encodedHistory: [String]) -> [RecztHistorySong] {
        let songs: [RecztHistorySong] = encodedHistory.compactMap { json in
            guard let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            let title = (object["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let artist = (object["artist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { return nil }
            return RecztHistorySong(
                title: title,
                artist: artist.isEmpty ? "Unknown Artist" : artist,
                albumCover: object["albumCover"] as? String,
                genre: object["genre"] as? String,
                emotion: object["emotion"] as? String,
                spotifyURL: object["spotifyUrl"] as? String,
                appleMusicURL: object["appleMusicUrl"] as? String
            )
        }
        replaceHistory(songs)
        return songs
    }

    func appendRecognitionResult(_ result: RecztRecognitionResult) {
        lock.withLock {
            var values: [RecztRecognitionResult] = []
            if let data = defaults.data(forKey: RecztSharedConstants.pendingResultsKey),
               let decoded = try? decoder.decode([RecztRecognitionResult].self, from: data) {
                values = decoded
            }
            values.removeAll { $0.id == result.id }
            values.insert(result, at: 0)
            values = Array(values.prefix(30))
            if let data = try? encoder.encode(values) {
                defaults.set(data, forKey: RecztSharedConstants.pendingResultsKey)
            }
        }

        var songs = history()
        let historySong = RecztHistorySong(
            title: result.title,
            artist: result.artist,
            albumCover: result.albumCover,
            genre: result.genre,
            emotion: result.emotion,
            spotifyURL: result.spotifyURL,
            appleMusicURL: result.appleMusicURL
        )
        songs.removeAll { $0.id == historySong.id }
        songs.insert(historySong, at: 0)
        replaceHistory(songs)
    }

    func drainRecognitionResults() -> [RecztRecognitionResult] {
        lock.withLock {
            guard let data = defaults.data(forKey: RecztSharedConstants.pendingResultsKey),
                  let values = try? decoder.decode([RecztRecognitionResult].self, from: data) else {
                return []
            }
            defaults.removeObject(forKey: RecztSharedConstants.pendingResultsKey)
            return values
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
