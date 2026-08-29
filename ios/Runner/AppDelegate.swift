import UIKit
import Flutter
import AppIntents
import AVFoundation
import Speech

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

        let utterance = AVSpeechUtterance(string: prompt)
        utterance.voice =
            AVSpeechSynthesisVoice(language: localeIdentifier)
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        startListening()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
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

            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )

            callback?(choice)
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

        GeneratedPluginRegistrant.register(with: self)

        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
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
