import UIKit
import Flutter
import AppIntents
import AVFoundation
import Speech
import UserNotifications

class SiriBridge {
    static var channel: FlutterMethodChannel?

    static func sendSiriSignal() {
        UserDefaults.standard.set(true, forKey: "flutter.launchedFromSiri")

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        DispatchQueue.main.async {
            SiriBridge.channel?.invokeMethod(
                "startSiriRecognition",
                arguments: nil
            )
        }
    }
}

// Native hands-free "first or second?" chooser.
// Apple doesn't expose Siri as a general in-app conversational API, so Reczt
// uses the native speech synthesizer and Speech framework for the interaction.
final class VoiceChoiceBridge: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = VoiceChoiceBridge()

    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutWorkItem: DispatchWorkItem?
    private var pendingResult: FlutterResult?
    private var localeIdentifier = "en-US"
    private var firstPhrases: [String] = []
    private var secondPhrases: [String] = []

    // Number of queued speech segments still being spoken. We only start
    // listening after the final segment finishes.
    private var pendingSpeechSegments = 0

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func prepare(result: @escaping FlutterResult) {
        authorizeSpeech { authorized in
            DispatchQueue.main.async {
                result(authorized)
            }
        }
    }

    func ask(arguments: [String: Any], result: @escaping FlutterResult) {
        guard pendingResult == nil else {
            result(
                FlutterError(
                    code: "VOICE_CHOICE_BUSY",
                    message: "A voice choice is already active.",
                    details: nil
                )
            )
            return
        }

        guard
            let prompt = arguments["prompt"] as? String,
            !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            result(nil)
            return
        }

        localeIdentifier =
            arguments["locale"] as? String ?? "en-US"
        firstPhrases = arguments["firstPhrases"] as? [String] ?? []
        secondPhrases = arguments["secondPhrases"] as? [String] ?? []
        pendingResult = result

        authorizeSpeech { [weak self] authorized in
            guard let self = self else { return }

            guard authorized else {
                self.finish(choice: nil)
                return
            }

            DispatchQueue.main.async {
                self.speak(prompt)
            }
        }
    }

    private func authorizeSpeech(
        completion: @escaping (Bool) -> Void
    ) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            completion(true)

        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                completion(status == .authorized)
            }

        case .denied, .restricted:
            completion(false)

        @unknown default:
            completion(false)
        }
    }

    /// Pick a warm, consistent installed voice for the current language.
    ///
    /// Reczt now prefers a short list of natural Apple voices by language first,
    /// then chooses the best-quality non-novelty fallback. This avoids a different
    /// or unexpectedly robotic voice winning simply because its quality score is
    /// slightly higher on a particular device.
    private func preferredSpeechVoice() -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let requestedLocale = Locale(identifier: localeIdentifier)
        let requestedLanguage = requestedLocale.languageCode?.lowercased()

        let compatibleVoices = allVoices.filter { voice in
            let voiceLocale = Locale(identifier: voice.language)
            let voiceLanguage = voiceLocale.languageCode?.lowercased()

            return voice.language.caseInsensitiveCompare(localeIdentifier) == .orderedSame
                || (
                    requestedLanguage != nil
                    && voiceLanguage == requestedLanguage
                )
        }

        guard !compatibleVoices.isEmpty else {
            return AVSpeechSynthesisVoice(language: localeIdentifier)
        }

        let noveltyNames = [
            "bad news", "bahh", "bells", "boing", "bubbles", "cellos",
            "deranged", "good news", "hysterical", "organ", "trinoids",
            "whisper", "wobble", "zarvox"
        ]

        let safeVoices = compatibleVoices.filter { voice in
            let name = voice.name.lowercased()
            return !noveltyNames.contains(where: { name.contains($0) })
        }

        // Ordered by the tone Reczt is aiming for: warm and conversational,
        // with locale-appropriate alternatives where Apple provides them.
        let preferredNamesByLanguage: [String: [String]] = [
            "en": ["ava", "samantha", "allison", "zoe", "serena", "susan", "karen", "moira", "tessa"],
            "es": ["monica", "paulina", "luciana"],
            "fr": ["audrey", "amelie"],
            "de": ["anna"],
            "it": ["alice"],
            "ja": ["kyoko"],
            "ko": ["yuna"],
            "zh": ["ting-ting"],
            "pl": ["zosia"],
            "ru": ["milena"],
            "hi": ["lekha"]
        ]

        let preferredNames = preferredNamesByLanguage[requestedLanguage ?? ""] ?? []

        func fallbackScore(_ voice: AVSpeechSynthesisVoice) -> Int {
            var total = 0
            if voice.language.caseInsensitiveCompare(localeIdentifier) == .orderedSame {
                total += 5000
            }
            total += voice.quality.rawValue * 3000
            if voice.gender == .female {
                total += 400
            }
            return total
        }

        // Prefer the named conversational voice first, but choose the best-quality
        // installed variant of that voice (default/enhanced/premium).
        for preferredName in preferredNames {
            let matches = safeVoices.filter {
                $0.name.lowercased().contains(preferredName)
            }
            if let selected = matches.max(by: {
                fallbackScore($0) < fallbackScore($1)
            }) {
                print(
                    "Reczt voice: \(selected.name), \(selected.language), quality=\(selected.quality.rawValue)"
                )
                return selected
            }
        }

        let selected = safeVoices.max {
            fallbackScore($0) < fallbackScore($1)
        }

        if let selected = selected {
            print(
                "Reczt voice fallback: \(selected.name), \(selected.language), quality=\(selected.quality.rawValue)"
            )
        }

        return selected ?? AVSpeechSynthesisVoice(language: localeIdentifier)
    }

    /// Break a long prompt into natural spoken phrases. AVSpeechSynthesizer
    /// handles punctuation better when each sentence is its own utterance, and
    /// postUtteranceDelay gives the listener a real conversational pause.
    private func speechSegments(from prompt: String) -> [String] {
        let cleaned = prompt
            .replacingOccurrences(of: ":", with: ": ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return [] }

        let sentencePattern = #"[^.!?。！？]+[.!?。！？]?"#
        guard
            let regex = try? NSRegularExpression(
                pattern: sentencePattern,
                options: []
            )
        else {
            return [cleaned]
        }

        let nsRange = NSRange(
            cleaned.startIndex..<cleaned.endIndex,
            in: cleaned
        )

        let pieces = regex.matches(
            in: cleaned,
            options: [],
            range: nsRange
        ).compactMap { match -> String? in
            guard let range = Range(match.range, in: cleaned) else {
                return nil
            }

            let piece = String(cleaned[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return piece.isEmpty ? nil : piece
        }

        return pieces.isEmpty ? [cleaned] : pieces
    }

    private func speak(_ prompt: String) {
        stopRecognition()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.allowBluetooth, .defaultToSpeaker, .duckOthers]
            )
            try session.setActive(true)
        } catch {
            print("Voice choice speech session error: \(error)")
        }

        let segments = speechSegments(from: prompt)
        guard !segments.isEmpty else {
            finish(choice: nil)
            return
        }

        let voice = preferredSpeechVoice()
        pendingSpeechSegments = segments.count

        for (index, segment) in segments.enumerated() {
            let utterance = AVSpeechUtterance(string: segment)
            utterance.voice = voice

            // Apple's voices generally sound most natural near their
            // normal conversational rate. Slowing them too much can actually
            // make them sound more robotic.
            let normalized = segment.lowercased()
            let isChoiceLine =
                normalized.contains("first")
                || normalized.contains("second")
                || normalized.contains("premier")
                || normalized.contains("deuxième")
                || normalized.contains("erste")
                || normalized.contains("zweite")

            // A slightly quicker, more conversational cadence sounds less robotic
            // with Apple's enhanced/premium voices while keeping song choices clear.
            utterance.rate = isChoiceLine ? 0.50 : 0.53
            utterance.pitchMultiplier = 1.02
            utterance.volume = 0.98

            // A short lead-in prevents the first word from feeling clipped.
            if index == 0 {
                utterance.preUtteranceDelay = 0.10
            }

            // Keep enough separation to distinguish two song choices without the
            // long synthetic pauses that made the old prompt sound mechanical.
            if index == segments.count - 1 {
                utterance.postUtteranceDelay = 0.18
            } else if index == 1 || index == 2 {
                utterance.postUtteranceDelay = 0.40
            } else {
                utterance.postUtteranceDelay = 0.26
            }

            synthesizer.speak(utterance)
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        pendingSpeechSegments = max(0, pendingSpeechSegments - 1)

        if pendingSpeechSegments == 0 {
            startListening()
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        pendingSpeechSegments = 0
        finish(choice: nil)
    }

    private func startListening() {
        guard
            let recognizer =
                SFSpeechRecognizer(
                    locale: Locale(identifier: localeIdentifier)
                ),
            recognizer.isAvailable
        else {
            finish(choice: nil)
            return
        }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .confirmation

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            finish(choice: nil)
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.allowBluetooth, .defaultToSpeaker, .duckOthers]
            )
            try session.setActive(true)

            inputNode.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: format
            ) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()
        } catch {
            print("Voice choice listening error: \(error)")
            finish(choice: nil)
            return
        }

        audioEngine = engine
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(
            with: request
        ) { [weak self] speechResult, error in
            guard let self = self else { return }

            if let speechResult = speechResult {
                let text =
                    speechResult.bestTranscription.formattedString

                if let choice = self.choiceIndex(from: text) {
                    self.finish(choice: choice)
                    return
                }

                if speechResult.isFinal {
                    self.finish(choice: nil)
                    return
                }
            }

            if error != nil {
                self.finish(choice: nil)
            }
        }

        let timeout = DispatchWorkItem { [weak self] in
            self?.finish(choice: nil)
        }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 7.0,
            execute: timeout
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: localeIdentifier)
            )
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matches(
        spoken: String,
        phrases: [String]
    ) -> Bool {
        for phrase in phrases {
            let normalizedPhrase = normalize(phrase)
            if normalizedPhrase.isEmpty {
                continue
            }

            if spoken == normalizedPhrase {
                return true
            }

            if normalizedPhrase.count >= 2 &&
                spoken.contains(normalizedPhrase) {
                return true
            }
        }
        return false
    }

    private func choiceIndex(from transcription: String) -> Int? {
        let spoken = normalize(transcription)
        guard !spoken.isEmpty else { return nil }

        let first = matches(
            spoken: spoken,
            phrases: firstPhrases
        )
        let second = matches(
            spoken: spoken,
            phrases: secondPhrases
        )

        if first && !second { return 0 }
        if second && !first { return 1 }
        return nil
    }

    private func stopRecognition() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func finish(choice: Int?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.stopRecognition()

            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }

            let callback = self.pendingResult
            self.pendingResult = nil
            self.firstPhrases = []
            self.secondPhrases = []
            self.pendingSpeechSegments = 0

            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )

            callback?(choice)
        }
    }
}


// -----------------------------------------------------------------------------
// MARK: - Reliable offline queue upload bridge
// -----------------------------------------------------------------------------
//
// Offline recordings remain on-device until iOS can upload them. A single
// background URLSession owns file-based uploads; Apple can continue these
// transfers while Reczt is suspended and background sessions automatically wait
// for connectivity. The server does the recognition work, and iOS posts a local
// result notification when the background response arrives.
//
// The audio source file is deliberately NOT deleted here. Flutter imports the
// completed result into normal History first, preserves the user's singing clip,
// removes the item from its local queue, and only then deletes the queued source.

private struct OfflineUploadMetadata: Codable {
    let sourcePath: String
    let multipartBodyPath: String
    let jobID: String
    let language: String
    let environment: String
}

final class OfflineUploadManager: NSObject,
                                  URLSessionDelegate,
                                  URLSessionTaskDelegate,
                                  URLSessionDataDelegate {
    static let shared = OfflineUploadManager()
    static let sessionIdentifier = "com.reczt.app.offline-upload"

    private let completedResultsKey = "reczt.native.offline.results.v1"
    private var responseBuffers: [Int: Data] = [:]
    private var backgroundEventsCompletionHandler: (() -> Void)?

    /// Called only while a Flutter engine is alive. Background completions are
    /// also persisted in UserDefaults, so no result depends on this callback.
    var resultReadyHandler: (() -> Void)?

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(
            withIdentifier: Self.sessionIdentifier
        )
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 300
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil

        return URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
    }()

    private override init() {
        super.init()
        _ = session
    }

    func restoreBackgroundSession() {
        _ = session
    }


    private func metadata(from task: URLSessionTask) -> OfflineUploadMetadata? {
        guard
            let raw = task.taskDescription,
            let data = raw.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(OfflineUploadMetadata.self, from: data)
    }

    private func encodeMetadata(_ metadata: OfflineUploadMetadata) -> String? {
        guard
            let data = try? JSONEncoder().encode(metadata)
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func appendText(
        _ value: String,
        to data: inout Data
    ) {
        if let bytes = value.data(using: .utf8) {
            data.append(bytes)
        }
    }

    private func makeMultipartBody(
        audioURL: URL,
        fields: [String: String],
        boundary: String,
        jobID: String
    ) throws -> URL {
        let fileManager = FileManager.default
        let supportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = supportURL.appendingPathComponent(
            "RecztOfflineUploads",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let outputURL = directory.appendingPathComponent(
            "offline_upload_\(jobID).multipart"
        )

        var body = Data()
        for (name, value) in fields {
            appendText("--\(boundary)\r\n", to: &body)
            appendText(
                "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n",
                to: &body
            )
            appendText("\(value)\r\n", to: &body)
        }

        appendText("--\(boundary)\r\n", to: &body)
        appendText(
            "Content-Disposition: form-data; name=\"file\"; filename=\"queued_recording.wav\"\r\n",
            to: &body
        )
        appendText("Content-Type: audio/wav\r\n\r\n", to: &body)
        body.append(try Data(contentsOf: audioURL))
        appendText("\r\n--\(boundary)--\r\n", to: &body)

        try body.write(to: outputURL, options: .atomic)
        return outputURL
    }

    func scheduleUpload(
        sourcePath: String,
        backendURL: String,
        language: String,
        environment: String,
        completion: @escaping (Bool) -> Void
    ) {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            completion(false)
            return
        }
        guard let endpoint = URL(string: backendURL) else {
            completion(false)
            return
        }

        // Prevent duplicate uploads if Flutter asks us to reschedule the queue
        // after a resume/connectivity event.
        session.getAllTasks { [weak self] tasks in
            guard let self = self else {
                completion(false)
                return
            }

            let alreadyScheduled = tasks.contains { task in
                guard task.state != .completed else { return false }
                return self.metadata(from: task)?.sourcePath == sourcePath
            }
            if alreadyScheduled {
                completion(true)
                return
            }

            let jobID = UUID().uuidString.lowercased()
            let boundary = "RecztBoundary-\(UUID().uuidString)"

            let fields: [String: String] = [
                "language": language,
                "vocal_isolation": "true",
                "environment": environment,
                "auto_play": "false",
                "background_queue": "true"
            ]

            do {
                let bodyURL = try self.makeMultipartBody(
                    audioURL: sourceURL,
                    fields: fields,
                    boundary: boundary,
                    jobID: jobID
                )

                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue(
                    "multipart/form-data; boundary=\(boundary)",
                    forHTTPHeaderField: "Content-Type"
                )
                request.setValue(
                    "application/json",
                    forHTTPHeaderField: "Accept"
                )

                let metadata = OfflineUploadMetadata(
                    sourcePath: sourcePath,
                    multipartBodyPath: bodyURL.path,
                    jobID: jobID,
                    language: language,
                    environment: environment
                )

                let task = self.session.uploadTask(
                    with: request,
                    fromFile: bodyURL
                )
                task.taskDescription = self.encodeMetadata(metadata)
                task.resume()
                completion(true)
            } catch {
                print(
                    "Reczt offline upload could not be prepared: \(error.localizedDescription)"
                )
                completion(false)
            }
        }
    }

    func drainCompletedResults() -> [String] {
        let defaults = UserDefaults.standard
        let results = defaults.stringArray(forKey: completedResultsKey) ?? []
        defaults.removeObject(forKey: completedResultsKey)
        return results
    }

    func clearCompletedResults() {
        UserDefaults.standard.removeObject(forKey: completedResultsKey)
    }

    private func storeCompletedResult(_ result: [String: Any]) {
        guard
            JSONSerialization.isValidJSONObject(result),
            let data = try? JSONSerialization.data(withJSONObject: result),
            let string = String(data: data, encoding: .utf8)
        else {
            return
        }

        let defaults = UserDefaults.standard
        var results = defaults.stringArray(forKey: completedResultsKey) ?? []
        results.append(string)

        // Defensive cap only; normal use should contain zero or a handful.
        if results.count > 50 {
            results = Array(results.suffix(50))
        }
        defaults.set(results, forKey: completedResultsKey)

        DispatchQueue.main.async { [weak self] in
            self?.resultReadyHandler?()
        }
    }

    private func removeMultipartBody(for task: URLSessionTask) {
        guard let metadata = metadata(from: task) else { return }
        try? FileManager.default.removeItem(
            atPath: metadata.multipartBodyPath
        )
    }

    private func showOfflineResultNotification(
        title: String,
        artist: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Reczt"
        content.body = artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? title
            : "\(title) — \(artist)"
        content.sound = .default
        content.threadIdentifier = "reczt-offline"

        let request = UNNotificationRequest(
            identifier: "reczt-offline-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAllUploads(completion: @escaping () -> Void) {
        session.getAllTasks { [weak self] tasks in
            guard let self = self else {
                completion()
                return
            }
            for task in tasks {
                self.removeMultipartBody(for: task)
                task.cancel()
            }
            self.responseBuffers.removeAll()
            completion()
        }
    }

    func handleEvents(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) -> Bool {
        guard identifier == Self.sessionIdentifier else {
            return false
        }
        backgroundEventsCompletionHandler = completionHandler
        _ = session
        return true
    }

    // MARK: URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        responseBuffers[dataTask.taskIdentifier, default: Data()].append(data)
    }

    // MARK: URLSessionTaskDelegate

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        defer {
            removeMultipartBody(for: task)
            responseBuffers.removeValue(forKey: task.taskIdentifier)
        }

        guard error == nil else {
            print(
                "Reczt offline upload ended with a network error: \(error!.localizedDescription)"
            )
            // Flutter keeps the original queued source file. It can be
            // rescheduled when Reczt next resumes.
            return
        }

        guard
            let httpResponse = task.response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode),
            let data = responseBuffers[task.taskIdentifier],
            let object = try? JSONSerialization.jsonObject(with: data),
            var response = object as? [String: Any],
            response["success"] as? Bool == true,
            let metadata = metadata(from: task)
        else {
            // A low-confidence/no-match response intentionally remains queued
            // so Reczt never turns a weak unattended guess into history.
            return
        }

        response["queued_path"] = metadata.sourcePath
        response["server_offline"] = true
        response["offline_job_id"] = metadata.jobID
        storeCompletedResult(response)

        // The background URLSession completion is allowed to run while Reczt is
        // in the background. Schedule a local notification immediately so the
        // user sees the result without requiring a remote push service.
        let title = response["title"] as? String ?? "Song found"
        let artist = response["artist"] as? String ?? ""
        showOfflineResultNotification(title: title, artist: artist)
    }

    // Called after all background-session delegate events have been delivered.
    func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        guard let handler = backgroundEventsCompletionHandler else {
            return
        }
        backgroundEventsCompletionHandler = nil
        DispatchQueue.main.async {
            handler()
        }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller =
            window?.rootViewController as! FlutterViewController

        let siriChannel = FlutterMethodChannel(
            name: "com.handsfreefinder/siri",
            binaryMessenger: controller.binaryMessenger
        )

        SiriBridge.channel = siriChannel

        siriChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "checkSiriTrigger":
                let launchedFromSiri =
                    UserDefaults.standard.bool(
                        forKey: "flutter.launchedFromSiri"
                    )

                if launchedFromSiri {
                    UserDefaults.standard.set(
                        false,
                        forKey: "flutter.launchedFromSiri"
                    )
                }

                result(launchedFromSiri)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let voiceChoiceChannel = FlutterMethodChannel(
            name: "reczt/voice_choice",
            binaryMessenger: controller.binaryMessenger
        )

        voiceChoiceChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "prepare":
                VoiceChoiceBridge.shared.prepare(result: result)

            case "askSongChoice":
                guard
                    let args = call.arguments as? [String: Any]
                else {
                    result(nil)
                    return
                }

                VoiceChoiceBridge.shared.ask(
                    arguments: args,
                    result: result
                )

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let offlineQueueChannel = FlutterMethodChannel(
            name: "reczt/offline_queue",
            binaryMessenger: controller.binaryMessenger
        )

        OfflineUploadManager.shared.resultReadyHandler = {
            offlineQueueChannel.invokeMethod(
                "offlineResultReady",
                arguments: nil
            )
        }

        offlineQueueChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "scheduleUpload":
                guard
                    let args = call.arguments as? [String: Any],
                    let filePath = args["filePath"] as? String,
                    let backendURL = args["backendUrl"] as? String
                else {
                    result(false)
                    return
                }

                let language = args["language"] as? String ?? "en"
                let environment =
                    args["environment"] as? String ?? "outdoors"

                OfflineUploadManager.shared.scheduleUpload(
                    sourcePath: filePath,
                    backendURL: backendURL,
                    language: language,
                    environment: environment
                ) { scheduled in
                    DispatchQueue.main.async {
                        result(scheduled)
                    }
                }

            case "drainCompletedResults":
                result(
                    OfflineUploadManager.shared.drainCompletedResults()
                )

            case "clearCompletedResults":
                OfflineUploadManager.shared.clearCompletedResults()
                result(nil)

            case "cancelAllUploads":
                OfflineUploadManager.shared.cancelAllUploads {
                    DispatchQueue.main.async {
                        result(nil)
                    }
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Reconnect to any URLSession transfers that iOS preserved while the
        // process was suspended/terminated.
        OfflineUploadManager.shared.restoreBackgroundSession()

        GeneratedPluginRegistrant.register(with: self)

        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }


    override func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        if OfflineUploadManager.shared.handleEvents(
            identifier: identifier,
            completionHandler: completionHandler
        ) {
            return
        }

        super.application(
            application,
            handleEventsForBackgroundURLSession: identifier,
            completionHandler: completionHandler
        )
    }
}

@available(iOS 16.0, *)
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: IdentifySongIntent(),
            phrases: [
                "Activate \(.applicationName)",
                "Find Song With \(.applicationName)"
            ],
            shortTitle: "Identify Song",
            systemImageName: "waveform"
        )
    }
}

@available(iOS 16.0, *)
struct IdentifySongIntent: AppIntent {
    static var title: LocalizedStringResource = "Identify Song"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        SiriBridge.sendSiriSignal()
        return .result()
    }
}