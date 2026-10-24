import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct RecztRecognitionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecztRecognitionAttributes.self) { context in
            Group {
                if context.attributes.isChristmas {
                    RecztChristmasLockScreen(state: context.state)
                } else {
                    standardLockScreen(for: context.state)
                }
            }
            .activityBackgroundTint(context.attributes.isChristmas ? RecztChristmasPalette.navy : .black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let christmas = context.attributes.isChristmas
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if christmas {
                        RecztChristmasSnowman().frame(width: 36, height: 36)
                    } else {
                        statusIcon(for: context.state).font(.title2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailingStatus(for: context.state, christmas: christmas, compact: false)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(expandedTitle(for: context.state))
                        .font(.headline)
                        .foregroundStyle(christmas ? RecztChristmasPalette.snow : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: christmas ? 6 : 3) {
                        if christmas {
                            RecztChristmasGarland(highlight: lightHighlight(for: context.state))
                                .frame(height: 12)
                        }
                        if !christmas || context.state.phase == "found" {
                            Text(context.state.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(christmas ? RecztChristmasPalette.snow : .white)
                                .lineLimit(1)
                        }
                        Text(christmas && context.state.phase == "searching" ? "Matching the melody" : context.state.artist)
                            .font(.caption)
                            .foregroundStyle(christmas ? RecztChristmasPalette.snow.opacity(0.75) : .white.opacity(0.65))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, christmas ? 4 : 0)
                }
            } compactLeading: {
                if christmas {
                    RecztChristmasSnowman().frame(width: 20, height: 20)
                } else {
                    statusIcon(for: context.state).font(.caption.weight(.bold))
                }
            } compactTrailing: {
                trailingStatus(for: context.state, christmas: christmas, compact: true)
            } minimal: {
                if christmas {
                    ZStack(alignment: .bottomTrailing) {
                        RecztChristmasSnowman().frame(width: 20, height: 20)
                        if context.state.phase == "found" {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(RecztChristmasPalette.gold)
                                .background(Circle().fill(RecztChristmasPalette.navy))
                        } else if ["noMatch", "error", "denied"].contains(context.state.phase) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(RecztChristmasPalette.gold)
                                .background(Circle().fill(RecztChristmasPalette.navy))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(expandedTitle(for: context.state))
                } else {
                    statusIcon(for: context.state).font(.caption2)
                }
            }
            .keylineTint(christmas ? RecztChristmasPalette.gold : .orange)
        }
    }

    private func standardLockScreen(for state: RecztRecognitionAttributes.ContentState) -> some View {
        HStack(spacing: 12) {
            statusIcon(for: state).font(.title2).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title).font(.headline).lineLimit(1)
                Text(state.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if state.phase == "listening" && state.secondsRemaining > 0 {
                Text("\(state.secondsRemaining)s")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func trailingStatus(for state: RecztRecognitionAttributes.ContentState, christmas: Bool, compact: Bool) -> some View {
        if state.phase == "listening" && state.secondsRemaining > 0 {
            Text(compact ? "\(state.secondsRemaining)" : "\(state.secondsRemaining)s")
                .font(compact ? .caption2.monospacedDigit() : .headline.monospacedDigit())
                .foregroundStyle(christmas ? RecztChristmasPalette.gold : .white)
                .contentTransition(.numericText())
                .accessibilityLabel("\(state.secondsRemaining) seconds remaining")
        } else if state.phase == "found" {
            Image(systemName: compact ? "checkmark" : "checkmark.circle.fill")
                .foregroundStyle(christmas ? RecztChristmasPalette.gold : .green)
                .accessibilityLabel("Song found")
        } else if compact || christmas {
            Image(systemName: ["noMatch", "error", "denied"].contains(state.phase) ? "exclamationmark.circle" : "waveform")
                .foregroundStyle(christmas ? RecztChristmasPalette.gold : .white)
                .accessibilityLabel(expandedTitle(for: state))
        }
    }

    @ViewBuilder
    private func statusIcon(for state: RecztRecognitionAttributes.ContentState) -> some View {
        switch state.phase {
        case "found":
            Image(systemName: "music.note").foregroundStyle(.orange)
        case "searching":
            Image(systemName: "waveform.badge.magnifyingglass").foregroundStyle(.purple)
        case "noMatch", "error", "denied":
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        default:
            Image(systemName: "waveform.badge.mic").foregroundStyle(.orange).symbolEffect(.pulse)
        }
    }

    private func expandedTitle(for state: RecztRecognitionAttributes.ContentState) -> String {
        RecztActivityPresentation.headline(for: state)
    }

    private func lightHighlight(for state: RecztRecognitionAttributes.ContentState) -> Int {
        state.phase == "listening" ? max(0, state.secondsRemaining) % 7 : -1
    }
}

private enum RecztActivityPresentation {
    static func headline(for state: RecztRecognitionAttributes.ContentState) -> String {
        switch state.phase {
        case "found": return "Song found"
        case "searching": return "Finding your song"
        case "noMatch": return "No match"
        case "denied": return "Microphone access needed"
        case "error": return "Recognition unavailable"
        case "cancelled", "idle": return "Recognition ended"
        default: return "Reczt is listening"
        }
    }

}

private enum RecztChristmasPalette {
    static let navy = Color(red: 0.025, green: 0.075, blue: 0.14)
    static let snow = Color(red: 0.94, green: 0.97, blue: 1)
    static let gold = Color(red: 0.97, green: 0.80, blue: 0.47)
    static let red = Color(red: 0.78, green: 0.14, blue: 0.21)
    static let pine = Color(red: 0.40, green: 0.74, blue: 0.52)
}

private struct RecztChristmasLockScreen: View {
    let state: RecztRecognitionAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            RecztChristmasGarland(highlight: state.phase == "listening" ? max(0, state.secondsRemaining) % 7 : -1)
                .frame(height: 12)
            HStack(spacing: 12) {
                RecztChristmasSnowman().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("RECZT · HOLIDAY LIGHTS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(RecztChristmasPalette.gold)
                    Text(state.phase == "found" ? state.title : RecztActivityPresentation.headline(for: state))
                        .font(.headline)
                        .foregroundStyle(RecztChristmasPalette.snow)
                        .lineLimit(1)
                    Text(state.phase == "searching" ? "Matching the melody" : state.artist)
                        .font(.caption)
                        .foregroundStyle(RecztChristmasPalette.snow.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if state.phase == "listening" && state.secondsRemaining > 0 {
                    Text("\(state.secondsRemaining)s")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(RecztChristmasPalette.gold)
                        .accessibilityLabel("\(state.secondsRemaining) seconds remaining")
                } else {
                    Image(systemName: terminalSymbol)
                        .foregroundStyle(RecztChristmasPalette.gold)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(LinearGradient(colors: [RecztChristmasPalette.navy, Color(red: 0.04, green: 0.12, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var terminalSymbol: String {
        switch state.phase {
        case "found": return "music.note"
        case "noMatch", "error", "denied": return "exclamationmark.circle"
        case "cancelled", "idle": return "stop.circle"
        default: return "waveform.badge.magnifyingglass"
        }
    }
}

/// Vector art keeps the tiny compact/minimal symbol sharp without new assets.
private struct RecztChristmasSnowman: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 32, y: size.height / 32)
            var arms = Path()
            arms.move(to: CGPoint(x: 9, y: 20))
            arms.addLine(to: CGPoint(x: 2, y: 15))
            arms.addLine(to: CGPoint(x: 2, y: 12))
            arms.move(to: CGPoint(x: 23, y: 20))
            arms.addLine(to: CGPoint(x: 29, y: 16))
            context.stroke(arms, with: .color(RecztChristmasPalette.gold), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            context.fill(Path(ellipseIn: CGRect(x: 7, y: 14, width: 19, height: 17)), with: .color(RecztChristmasPalette.snow))
            context.fill(Path(ellipseIn: CGRect(x: 11, y: 5, width: 13, height: 13)), with: .color(RecztChristmasPalette.snow))
            var hat = Path()
            hat.move(to: CGPoint(x: 11, y: 7))
            hat.addQuadCurve(to: CGPoint(x: 21, y: 1), control: CGPoint(x: 12, y: -1))
            hat.addQuadCurve(to: CGPoint(x: 25, y: 7), control: CGPoint(x: 25, y: 1))
            hat.closeSubpath()
            context.fill(hat, with: .color(RecztChristmasPalette.red))
            context.fill(Path(roundedRect: CGRect(x: 10, y: 6, width: 16, height: 3), cornerRadius: 1.5), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: 19, y: 0, width: 5, height: 4)), with: .color(.white))
            context.fill(Path(roundedRect: CGRect(x: 10, y: 16, width: 15, height: 3.5), cornerRadius: 1), with: .color(RecztChristmasPalette.red))
            context.fill(Path(roundedRect: CGRect(x: 21, y: 18, width: 3, height: 7), cornerRadius: 1), with: .color(RecztChristmasPalette.red))
            var nose = Path()
            nose.move(to: CGPoint(x: 22, y: 11))
            nose.addLine(to: CGPoint(x: 29, y: 12))
            nose.addLine(to: CGPoint(x: 22, y: 13))
            nose.closeSubpath()
            context.fill(nose, with: .color(RecztChristmasPalette.gold))
            for point in [CGPoint(x: 20, y: 9.5), CGPoint(x: 17, y: 22), CGPoint(x: 17, y: 26)] {
                context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 1.5, height: 1.5)), with: .color(RecztChristmasPalette.navy))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Highlight follows real countdown updates. No animation timer, background
/// refresh loop, or extra ActivityKit requests are needed for decoration.
private struct RecztChristmasGarland: View {
    let highlight: Int

    var body: some View {
        Canvas { context, size in
            var cable = Path()
            cable.move(to: .zero)
            cable.addQuadCurve(to: CGPoint(x: size.width, y: 0), control: CGPoint(x: size.width / 2, y: 9))
            context.stroke(cable, with: .color(RecztChristmasPalette.snow.opacity(0.35)), lineWidth: 1)
            let colors = [RecztChristmasPalette.red, RecztChristmasPalette.pine, RecztChristmasPalette.gold]
            for index in 0..<7 {
                let fraction = Double(index + 1) / 8
                let x = size.width * fraction
                let y = 2 + sin(fraction * .pi) * 3
                let color = colors[index % colors.count]
                context.fill(Path(ellipseIn: CGRect(x: x - 6, y: y - 3, width: 12, height: 12)), with: .color(color.opacity(index == highlight ? 0.3 : 0.08)))
                context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y, width: 4, height: 6)), with: .color(color.opacity(index == highlight ? 1 : 0.65)))
                if index == highlight {
                    context.fill(Path(ellipseIn: CGRect(x: x - 0.6, y: y + 1, width: 1.2, height: 3)), with: .color(.white))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
private enum RecztChristmasPreview {
    static let attributes = RecztRecognitionAttributes(sessionID: "christmas-preview", startedAt: .now, environment: "quiet", seasonalTheme: "christmas")
    static let listening = RecztRecognitionAttributes.ContentState.listening(secondsRemaining: 8, source: "app")
    static let searching = RecztRecognitionAttributes.ContentState(phase: "searching", title: "Finding your song…", artist: "Matching the melody", secondsRemaining: 0, source: "app")
    static let found = RecztRecognitionAttributes.ContentState(phase: "found", title: "Christmas Time Is Here", artist: "Vince Guaraldi Trio", secondsRemaining: 0, source: "app")
    static let noMatch = RecztRecognitionAttributes.ContentState(phase: "noMatch", title: "No match yet", artist: "Try a little closer to the music", secondsRemaining: 0, source: "app")
}

#Preview("Christmas: Expanded", as: .dynamicIsland(.expanded), using: RecztChristmasPreview.attributes) {
    RecztRecognitionLiveActivityWidget()
} contentStates: {
    RecztChristmasPreview.listening
    RecztChristmasPreview.searching
    RecztChristmasPreview.found
    RecztChristmasPreview.noMatch
}

#Preview("Christmas: Compact", as: .dynamicIsland(.compact), using: RecztChristmasPreview.attributes) {
    RecztRecognitionLiveActivityWidget()
} contentStates: {
    RecztChristmasPreview.listening
    RecztChristmasPreview.found
}

#Preview("Christmas: Minimal", as: .dynamicIsland(.minimal), using: RecztChristmasPreview.attributes) {
    RecztRecognitionLiveActivityWidget()
} contentStates: {
    RecztChristmasPreview.listening
}

#Preview("Christmas: Lock Screen", as: .content, using: RecztChristmasPreview.attributes) {
    RecztRecognitionLiveActivityWidget()
} contentStates: {
    RecztChristmasPreview.listening
    RecztChristmasPreview.searching
    RecztChristmasPreview.found
    RecztChristmasPreview.noMatch
}
#endif
