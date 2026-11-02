import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct RecztRecognitionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        return ActivityConfiguration(for: RecztRecognitionAttributes.self) { context in
            let copy = RecztActivityCopy(language: context.state.language ?? RecztSharedStore.shared.recognitionSettings().language)
            RecztActivityLockScreen(state: context.state, style: RecztActivityStyle(context.attributes), copy: copy)
                .environment(\.layoutDirection, copy.direction)
                .activityBackgroundTint(RecztActivityStyle(context.attributes).night)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let style = RecztActivityStyle(context.attributes)
            let copy = RecztActivityCopy(language: context.state.language ?? RecztSharedStore.shared.recognitionSettings().language)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if style.seasonal {
                        RecztAnimatedMark(style: style, state: context.state).frame(width: style == .christmas ? 42 : 38, height: style == .christmas ? 42 : 38)
                    } else {
                        RecztActivityStatus(state: context.state).font(.title2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RecztActivityTrailing(state: context.state, style: style, copy: copy, compact: false)
                        .frame(height: style == .christmas ? 42 : nil)
                }
                DynamicIslandExpandedRegion(.center) {
                    if style != .christmas {
                        Text(copy.headline(context.state)).font(.headline)
                            .foregroundStyle(style.snow).lineLimit(1).minimumScaleFactor(0.75)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: style == .christmas ? .leading : .center,
                           spacing: style == .christmas ? 7 : style.seasonal ? 6 : 3) {
                        if style == .halloween {
                            RecztActivityTrim(style: style, state: context.state)
                                .frame(height: 30).accessibilityHidden(true)
                        }
                        // Christmas status gets a full-width row below the camera.
                        if style == .christmas {
                            Text(copy.headline(context.state)).font(.headline)
                                .foregroundStyle(style.snow).lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if context.state.phase == "found" {
                            Text(context.state.title).font(.subheadline.weight(.semibold))
                                .foregroundStyle(style.snow).lineLimit(1)
                        }
                        Text(copy.subtitle(context.state)).font(.caption)
                            .foregroundStyle(style.snow.opacity(0.75)).lineLimit(style == .christmas ? 2 : 1)
                            .fixedSize(horizontal: false, vertical: style == .christmas)
                        if style == .christmas {
                            RecztActivityTrim(style: style, state: context.state)
                                .frame(height: style == .christmas ? 22 : 24)
                                .padding(.top, 2).accessibilityHidden(true)
                        }
                    }.frame(maxWidth: .infinity, alignment: style == .christmas ? .leading : .center)
                        .padding(.horizontal, style == .christmas ? 3 : 0)
                        .padding(.bottom, style == .christmas ? 7 : style.seasonal ? 4 : 0)
                        .environment(\.layoutDirection, copy.direction)
                }
            } compactLeading: {
                if style.seasonal {
                    RecztAnimatedMark(style: style, state: context.state).frame(width: 22, height: 22)
                } else {
                    RecztActivityStatus(state: context.state).font(.caption.weight(.bold))
                }
            } compactTrailing: {
                RecztActivityTrailing(state: context.state, style: style, copy: copy, compact: true)
            } minimal: {
                if style.seasonal {
                    ZStack(alignment: .bottomTrailing) {
                        RecztAnimatedMark(style: style, state: context.state).frame(width: 23, height: 23)
                        if context.state.phase == "found" {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 9, weight: .bold))
                                .foregroundStyle(style.accent).background(Circle().fill(style.night))
                        } else if ["noMatch", "error", "denied"].contains(context.state.phase) {
                            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 9, weight: .bold))
                                .foregroundStyle(style.accent).background(Circle().fill(style.night))
                        }
                    }.accessibilityElement(children: .ignore).accessibilityLabel(copy.headline(context.state))
                } else {
                    RecztActivityStatus(state: context.state).font(.caption2)
                }
            }.keylineTint(style.accent)
        }
    }
}

private enum RecztActivityStyle: Equatable {
    case standard, halloween, christmas
    init(_ attributes: RecztRecognitionAttributes) {
        self = attributes.isHalloween ? .halloween : attributes.isChristmas ? .christmas : .standard
    }
    var seasonal: Bool { self != .standard }
    var night: Color {
        self == .halloween ? Color(red: 0.12, green: 0.065, blue: 0.20) :
            self == .christmas ? Color(red: 0.025, green: 0.075, blue: 0.14) : .black.opacity(0.88)
    }
    var accent: Color {
        self == .halloween ? Color(red: 1, green: 0.66, blue: 0.32) :
            self == .christmas ? Color(red: 0.97, green: 0.80, blue: 0.47) : .orange
    }
    var snow: Color { self == .halloween ? Color(red: 0.96, green: 0.91, blue: 0.99) : Color(red: 0.94, green: 0.97, blue: 1) }
}

private struct RecztActivityLockScreen: View {
    let state: RecztRecognitionAttributes.ContentState
    let style: RecztActivityStyle
    let copy: RecztActivityCopy
    var body: some View {
        VStack(spacing: 8) {
            if style.seasonal {
                RecztActivityTrim(style: style, state: state)
                    .frame(height: 30).accessibilityHidden(true)
            }
            HStack(spacing: 12) {
                if style.seasonal {
                    RecztAnimatedMark(style: style, state: state).frame(width: 42, height: 42)
                } else {
                    RecztActivityStatus(state: state).font(.title2).frame(width: 32)
                }
                VStack(alignment: .leading, spacing: 3) {
                    if style.seasonal {
                        Text("RECZT").font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(2).foregroundStyle(style.accent)
                    }
                    Text(state.phase == "found" ? state.title : copy.headline(state))
                        .font(.headline).foregroundStyle(style.snow).lineLimit(1)
                    Text(copy.subtitle(state)).font(.caption)
                        .foregroundStyle(style.snow.opacity(0.75)).lineLimit(1)
                }
                Spacer(minLength: 4)
                RecztActivityTrailing(state: state, style: style, copy: copy, compact: false)
            }
        }.padding(.horizontal, 16).padding(.top, style.seasonal ? 6 : 12).padding(.bottom, 12)
            .background(LinearGradient(colors: [style.night, style.night.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

private struct RecztActivityTrailing: View {
    let state: RecztRecognitionAttributes.ContentState
    let style: RecztActivityStyle
    let copy: RecztActivityCopy
    let compact: Bool
    var body: some View {
        Group {
            if state.phase == "listening" && state.secondsRemaining > 0 {
                HStack(spacing: 3) {
                    if !compact { Image(systemName: "timer").font(.caption).accessibilityHidden(true) }
                    if let end = state.listeningEndsAt {
                        Text(timerInterval: min(Date(), end)...end, countsDown: true, showsHours: false)
                            .monospacedDigit().frame(width: compact ? 32 : 48, alignment: .trailing)
                    } else {
                        Image(systemName: "waveform.badge.mic")
                    }
                }.font(compact ? .caption2 : .headline)
            } else if state.phase == "found" {
                Image(systemName: compact ? "checkmark" : "checkmark.circle.fill")
                    .accessibilityLabel(copy.headline(state))
            } else {
                Image(systemName: ["noMatch", "error", "denied"].contains(state.phase) ? "exclamationmark.circle" : "waveform.badge.mic")
                    .accessibilityLabel(copy.headline(state))
            }
        }.foregroundStyle(style.accent)
            .environment(\.locale, Locale(identifier: copy.language))
    }
}

private struct RecztActivityStatus: View {
    let state: RecztRecognitionAttributes.ContentState
    var body: some View {
        switch state.phase {
        case "found": Image(systemName: "music.note").foregroundStyle(.orange)
        case "searching": Image(systemName: "waveform.badge.magnifyingglass").foregroundStyle(.purple)
        case "noMatch", "error", "denied": Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        default: Image(systemName: "waveform.badge.mic").foregroundStyle(.orange)
        }
    }
}

/// WidgetKit animates brief changes triggered by real ActivityKit updates. There
/// is no timer, repeatForever, TimelineView or decoration-only activity request.
/// The system controls animation delivery and can show a static pose instead.
private struct RecztAnimatedMark: View {
    let style: RecztActivityStyle
    let state: RecztRecognitionAttributes.ContentState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var beat: Double {
        if state.phase == "listening" { return Double(max(0, state.secondsRemaining)) }
        return state.phase == "found" ? -2 : state.phase == "searching" ? 0 : -4
    }
    var body: some View {
        let celebrating = state.phase == "found"
        ZStack(alignment: .topTrailing) {
            RecztCharacterMark(style: style, step: reduceMotion ? 0 : beat,
                celebrating: celebrating, frowning: state.phase == "noMatch")
                .scaleEffect(celebrating && !reduceMotion ? 1.07 : 1)
                .offset(y: celebrating && !reduceMotion ? -1.5 : 0)
            Image(systemName: style == .christmas ? "snowflake" : "sparkles")
                .font(.system(size: 9, weight: .semibold)).foregroundStyle(style.accent)
                .symbolEffect(.bounce, value: reduceMotion ? false : celebrating)
                .opacity(celebrating ? 1 : 0)
        }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.42), value: beat)
            .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.5), value: celebrating)
            .accessibilityHidden(true)
    }
}

private struct RecztCharacterMark: View, Animatable {
    let style: RecztActivityStyle
    var step: Double
    let celebrating: Bool
    let frowning: Bool
    var animatableData: Double {
        get { step }
        set { step = newValue }
    }
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let sway = sin(step * 0.8)
            ZStack {
                if style == .halloween {
                    Group {
                        if frowning { Image("RecztPumpkinSad").resizable().scaledToFit() }
                        else { Image("RecztPumpkinClassic").resizable().scaledToFit() }
                    }.rotationEffect(.degrees(sway * 1.5))
                        .offset(y: celebrating ? -side * 0.025 : 0)
                } else {
                    ZStack {
                        Image("RecztSnowmanRearSkate").resizable().scaledToFit()
                            .rotationEffect(.radians(0.27 - max(0, sway) * 0.065), anchor: UnitPoint(x: 0.3075, y: 0.6875))
                            .offset(x: side * CGFloat(0.155 - max(0, sway) * 0.025), y: side * CGFloat(0.165 - max(0, sway) * 0.0175))
                        Image("RecztSnowmanFrontSkate").resizable().scaledToFit()
                            .rotationEffect(.radians(max(0, -sway) * 0.055), anchor: UnitPoint(x: 0.5975, y: 0.7825))
                            .offset(x: side * CGFloat(-0.03 + max(0, -sway) * 0.0225), y: side * CGFloat(-0.0175 - max(0, -sway) * 0.0175))
                        Image("RecztSnowmanScarf").resizable().scaledToFit()
                            .rotationEffect(.degrees(sway * 3), anchor: UnitPoint(x: 0.46, y: 0.36))
                        if frowning { Image("RecztSnowmanSadBody").resizable().scaledToFit() }
                        else { Image("RecztSnowmanBody").resizable().scaledToFit() }
                    }.rotationEffect(.degrees(sway * 1.1), anchor: .bottom)
                }
                RecztSeasonalMotes(style: style, step: step)
            }.frame(width: side, height: side)
        }
    }
}

/// Painted ornament replaces the old wire-and-dot Canvas. Only three tiny
/// particles interpolate during real recording/phase updates; no idle loop.
private struct RecztActivityTrim: View {
    let style: RecztActivityStyle
    let state: RecztRecognitionAttributes.ContentState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var step: Double { reduceMotion ? 0 : Double(state.secondsRemaining) }
    var body: some View {
        ZStack {
            if style == .christmas {
                Image("RecztChristmasGarland").resizable().scaledToFill()
            } else {
                Image("RecztHalloweenGarland").resizable().scaledToFill()
            }
            RecztSeasonalMotes(style: style, step: step)
        }.clipped()
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.85), value: step)
    }
}

private struct RecztSeasonalMotes: View, Animatable {
    let style: RecztActivityStyle
    var step: Double
    var animatableData: Double { get { step } set { step = newValue } }
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<3) { index in
                let phase = Double(index) * 2.1
                let x = 0.18 + Double(index) * 0.31 + sin(step * 0.35 + phase) * 0.05
                let y = 0.30 + sin(step * 0.55 + phase) * 0.24
                Image(systemName: style == .christmas ? "snowflake" : "sparkle")
                    .font(.system(size: max(2.5, min(6, geometry.size.height * 0.13))))
                    .foregroundStyle(style == .christmas ? Color.white : style.accent)
                    .opacity(0.35 + abs(sin(step * 0.65 + phase)) * 0.5)
                    .rotationEffect(.degrees(step * 5 + phase * 12))
                    .position(x: geometry.size.width * CGFloat(x), y: geometry.size.height * CGFloat(y))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct RecztActivityCopy {
    let language: String
    var direction: LayoutDirection { language.hasPrefix("ar") ? .rightToLeft : .leftToRight }
    func text(_ key: String) -> String {
        let base = language.replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init) ?? "en"
        return RecztRecognitionAttributes.localizedText(key, language: base)
    }
    func headline(_ state: RecztRecognitionAttributes.ContentState) -> String {
        switch state.phase {
        case "found": return text("activity_found")
        case "searching": return text("searching")
        case "noMatch": return text("activity_no_match")
        case "denied": return text("mic_denied")
        case "error": return text("activity_error")
        case "cancelled", "idle": return text("activity_ended")
        case "queued": return text("activity_queued")
        default: return text("listening")
        }
    }
    func subtitle(_ state: RecztRecognitionAttributes.ContentState) -> String {
        if state.phase == "listening" { return text("activity_listening_hint") }
        if state.phase == "searching" { return text("activity_search_hint") }
        if state.phase == "found" { return state.redirecting == true ? text("activity_redirecting") : text("activity_found_hint") }
        if state.phase == "noMatch" { return text("activity_no_match_hint") }
        if state.phase == "queued" { return text("activity_queued") }
        return ""
    }
    func seconds(_ count: Int) -> String {
        text("activity_seconds_remaining").replacingOccurrences(of: "{seconds}", with: String(count))
    }

}

#if DEBUG
private enum RecztSeasonalPreview {
    static let christmas: RecztRecognitionAttributes = .init(sessionID: "christmas-preview", startedAt: .now, environment: "quiet", seasonalTheme: "christmas")
    static let halloween: RecztRecognitionAttributes = .init(sessionID: "halloween-preview", startedAt: .now, environment: "quiet", seasonalTheme: "halloween")
    static let listening = RecztRecognitionAttributes.ContentState.listening(secondsRemaining: 8, source: "app")
    static let nextBeat = RecztRecognitionAttributes.ContentState.listening(secondsRemaining: 7, source: "app")
    static let searching = RecztRecognitionAttributes.ContentState(phase: "searching", title: "", artist: "", secondsRemaining: 0, source: "app")
    static let found = RecztRecognitionAttributes.ContentState(phase: "found", title: "Christmas Time Is Here", artist: "Vince Guaraldi Trio", secondsRemaining: 0, source: "app")
    static let noMatch = RecztRecognitionAttributes.ContentState(phase: "noMatch", title: "", artist: "", secondsRemaining: 0, source: "app")
}
#Preview("Halloween: Expanded", as: .dynamicIsland(.expanded), using: RecztSeasonalPreview.halloween) {
    RecztRecognitionLiveActivityWidget()
} contentStates: {
    RecztSeasonalPreview.listening
    RecztSeasonalPreview.nextBeat
    RecztSeasonalPreview.searching
    RecztSeasonalPreview.found
    RecztSeasonalPreview.noMatch
}
#Preview("Halloween: Compact", as: .dynamicIsland(.compact), using: RecztSeasonalPreview.halloween) {
    RecztRecognitionLiveActivityWidget()
} contentStates: { RecztSeasonalPreview.listening; RecztSeasonalPreview.nextBeat; RecztSeasonalPreview.found }
#Preview("Halloween: Minimal", as: .dynamicIsland(.minimal), using: RecztSeasonalPreview.halloween) {
    RecztRecognitionLiveActivityWidget()
} contentStates: { RecztSeasonalPreview.listening; RecztSeasonalPreview.found }
#Preview("Halloween: Lock Screen", as: .content, using: RecztSeasonalPreview.halloween) {
    RecztRecognitionLiveActivityWidget()
} contentStates: { RecztSeasonalPreview.listening; RecztSeasonalPreview.searching; RecztSeasonalPreview.found }
#Preview("Christmas: Expanded", as: .dynamicIsland(.expanded), using: RecztSeasonalPreview.christmas) {
    RecztRecognitionLiveActivityWidget()
} contentStates: { RecztSeasonalPreview.listening; RecztSeasonalPreview.nextBeat; RecztSeasonalPreview.searching; RecztSeasonalPreview.found }
#Preview("Christmas: Compact", as: .dynamicIsland(.compact), using: RecztSeasonalPreview.christmas) {
    RecztRecognitionLiveActivityWidget()
} contentStates: { RecztSeasonalPreview.listening; RecztSeasonalPreview.nextBeat; RecztSeasonalPreview.found }
#Preview("Christmas: Minimal", as: .dynamicIsland(.minimal), using: RecztSeasonalPreview.christmas) {
    RecztRecognitionLiveActivityWidget()
} contentStates: { RecztSeasonalPreview.listening; RecztSeasonalPreview.found }
#Preview("Christmas: Lock Screen", as: .content, using: RecztSeasonalPreview.christmas) {
    RecztRecognitionLiveActivityWidget()
} contentStates: { RecztSeasonalPreview.listening; RecztSeasonalPreview.searching; RecztSeasonalPreview.found }
#endif
