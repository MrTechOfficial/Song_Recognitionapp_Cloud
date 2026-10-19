import AVFoundation
import Foundation

#if canImport(MusicUnderstanding)
import MusicUnderstanding
#endif

final class RecztMusicUnderstandingService: @unchecked Sendable {
    static let shared = RecztMusicUnderstandingService()

    private init() {}

    func analyzePreview(at remoteURL: URL) async throws -> [String: Any] {
        #if canImport(MusicUnderstanding)
        if #available(iOS 27.0, *) {
            let (downloadURL, response) = try await URLSession.shared.download(from: remoteURL)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw NSError(
                    domain: "RecztMusicUnderstanding",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Music preview download failed."]
                )
            }

            let ext = remoteURL.pathExtension.isEmpty ? "m4a" : remoteURL.pathExtension
            let localURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("reczt-music-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: localURL)
            try FileManager.default.moveItem(at: downloadURL, to: localURL)
            defer { try? FileManager.default.removeItem(at: localURL) }

            let asset = AVURLAsset(
                url: localURL,
                options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            )
            let session = try await MusicUnderstandingSession(asset: asset)
            let results = try await session.analyze(
                for: [.rhythm, .key, .pace, .instrumentActivity, .loudness, .structure]
            )

            var summary: [String: Any] = [:]

            if let bpm = results.rhythm?.beatsPerMinute {
                summary["bpm"] = Double(bpm)
            }

            if let keyRanges = results.key?.ranges, !keyRanges.isEmpty {
                let dominant = keyRanges.max { lhs, rhs in
                    CMTimeGetSeconds(lhs.range.duration) < CMTimeGetSeconds(rhs.range.duration)
                }
                if let signature = dominant?.value {
                    summary["key"] = "\(displayTonic(signature.tonic)) \(signature.mode.rawValue.capitalized)"
                }
            }

            if let paceRanges = results.pace?.ranges, !paceRanges.isEmpty {
                var weightedSum = 0.0
                var totalDuration = 0.0
                for ranged in paceRanges {
                    let duration = max(0, CMTimeGetSeconds(ranged.range.duration))
                    weightedSum += ranged.value * duration
                    totalDuration += duration
                }
                if totalDuration > 0 {
                    summary["pace"] = weightedSum / totalDuration
                } else {
                    summary["pace"] = paceRanges.map(\.value).reduce(0, +) / Double(paceRanges.count)
                }
            }

            if let loudness = results.loudness {
                summary["loudness"] = Double(loudness.integrated.value)
            }

            if let activity = results.instrumentActivity?.activity {
                let categories: [(InstrumentActivityResult.Instrument, String)] = [
                    (.vocal, "Vocals"),
                    (.drum, "Drums"),
                    (.bass, "Bass"),
                    (.other, "Other"),
                ]
                var best: (name: String, value: Double)?
                for (instrument, name) in categories {
                    guard let values = activity[instrument], !values.isEmpty else { continue }
                    let average = values.map { Double($0.value) }.reduce(0, +) / Double(values.count)
                    if best == nil || average > best!.value {
                        best = (name, average)
                    }
                }
                if let best {
                    summary["dominantInstrument"] = best.name
                    summary["dominantInstrumentActivity"] = best.value
                }
            }

            if let structure = results.structure {
                summary["structureSections"] = structure.sections.count
                summary["structureSegments"] = structure.segments.count
                summary["structurePhrases"] = structure.phrases.count
            }

            return summary
        }
        #endif

        throw NSError(
            domain: "RecztMusicUnderstanding",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Music Understanding requires iOS 27."]
        )
    }

    #if canImport(MusicUnderstanding)
    @available(iOS 27.0, *)
    private func displayTonic(_ tonic: KeyResult.Tonic) -> String {
        switch tonic {
        case .aFlat: return "A♭"
        case .aSharp: return "A♯"
        case .a: return "A"
        case .bFlat: return "B♭"
        case .b: return "B"
        case .c: return "C"
        case .cSharp: return "C♯"
        case .d: return "D"
        case .dFlat: return "D♭"
        case .dSharp: return "D♯"
        case .eFlat: return "E♭"
        case .e: return "E"
        case .f: return "F"
        case .fSharp: return "F♯"
        case .g: return "G"
        case .gFlat: return "G♭"
        case .gSharp: return "G♯"
        @unknown default: return tonic.rawValue
        }
    }
    #endif
}
