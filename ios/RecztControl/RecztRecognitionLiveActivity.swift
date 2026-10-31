import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct RecztRecognitionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        let copy = RecztActivityCopy(language: RecztSharedStore.shared.recognitionSettings().language)
        return ActivityConfiguration(for: RecztRecognitionAttributes.self) { context in
            RecztActivityLockScreen(state: context.state, style: RecztActivityStyle(context.attributes), copy: copy)
                .environment(\.layoutDirection, copy.direction)
                .activityBackgroundTint(RecztActivityStyle(context.attributes).night)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let style = RecztActivityStyle(context.attributes)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if style.seasonal {
                        RecztAnimatedMark(style: style, state: context.state).frame(width: 38, height: 38)
                    } else {
                        RecztActivityStatus(state: context.state).font(.title2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RecztActivityTrailing(state: context.state, style: style, copy: copy, compact: false)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(copy.headline(context.state)).font(.headline)
                        .foregroundStyle(style.snow).lineLimit(1).minimumScaleFactor(0.75)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: style.seasonal ? 6 : 3) {
                        if style.seasonal {
                            RecztActivityTrim(style: style, highlight: context.state.phase == "listening" ? max(0, context.state.secondsRemaining) % 7 : -1)
                                .frame(height: 11).accessibilityHidden(true)
                        }
                        if context.state.phase == "found" {
                            Text(context.state.title).font(.subheadline.weight(.semibold))
                                .foregroundStyle(style.snow).lineLimit(1)
                        }
                        Text(copy.subtitle(context.state)).font(.caption)
                            .foregroundStyle(style.snow.opacity(0.75)).lineLimit(1)
                    }.padding(.bottom, style.seasonal ? 4 : 0)
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
                RecztActivityTrim(style: style, highlight: state.phase == "listening" ? max(0, state.secondsRemaining) % 7 : -1)
                    .frame(height: 11).accessibilityHidden(true)
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
                    if !compact { Image(systemName: "timer").font(.caption) }
                    Text("\(state.secondsRemaining)").monospacedDigit().contentTransition(.numericText())
                }.font(compact ? .caption2 : .headline)
                    .accessibilityLabel(copy.seconds(state.secondsRemaining))
            } else if state.phase == "found" {
                Image(systemName: compact ? "checkmark" : "checkmark.circle.fill")
                    .accessibilityLabel(copy.headline(state))
            } else {
                Image(systemName: ["noMatch", "error", "denied"].contains(state.phase) ? "exclamationmark.circle" : "waveform.badge.mic")
                    .accessibilityLabel(copy.headline(state))
            }
        }.foregroundStyle(style.accent)
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
        RecztCharacterMark(style: style, step: reduceMotion ? 0 : beat, celebrating: state.phase == "found")
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.42), value: beat)
            .accessibilityHidden(true)
    }
}

private struct RecztCharacterMark: View, Animatable {
    let style: RecztActivityStyle
    var step: Double
    let celebrating: Bool
    var animatableData: Double {
        get { step }
        set { step = newValue }
    }
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 40, y: size.height / 40)
            if style == .halloween { pumpkin(&context) } else { snowman(&context) }
        }
    }
    private func pumpkin(_ context: inout GraphicsContext) {
        let ink = Color(red: 0.22, green: 0.10, blue: 0.19)
        let body = Path(ellipseIn: CGRect(x: 5, y: 12, width: 30, height: 25))
        context.fill(body, with: .linearGradient(Gradient(colors: [Color(red: 0.94, green: 0.49, blue: 0.20), Color(red: 0.65, green: 0.25, blue: 0.12)]), startPoint: CGPoint(x: 12, y: 12), endPoint: CGPoint(x: 31, y: 37)))
        context.stroke(body, with: .color(ink), lineWidth: 1)
        for x in [12.0, 20, 28] {
            var rib = Path(); rib.move(to: CGPoint(x: 20, y: 13))
            rib.addQuadCurve(to: CGPoint(x: 20, y: 36), control: CGPoint(x: x + (x - 20) * 0.5, y: 24))
            context.stroke(rib, with: .color(ink.opacity(0.22)), lineWidth: 0.8)
        }
        var stem = Path(); stem.move(to: CGPoint(x: 19, y: 13))
        stem.addQuadCurve(to: CGPoint(x: 24, y: 7), control: CGPoint(x: 17, y: 5))
        context.stroke(stem, with: .color(Color(red: 0.48, green: 0.59, blue: 0.37)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        let glance = sin(step * 0.8) * 0.45
        let open = max(0.16, 1 - pow(max(0, sin(step * 0.75)), 10) * 0.84)
        for x in [13.0, 26] {
            var eye = Path(); eye.move(to: CGPoint(x: x + glance, y: 21 - 3 * open))
            eye.addLine(to: CGPoint(x: x - 3.5 + glance, y: 22 + 2 * open))
            eye.addLine(to: CGPoint(x: x + 3.5 + glance, y: 22 + 2 * open)); eye.closeSubpath()
            context.fill(eye, with: .color(Color(red: 1, green: 0.85, blue: 0.40)))
        }
        var grin = Path(); grin.move(to: CGPoint(x: 11, y: 28))
        grin.addQuadCurve(to: CGPoint(x: 29, y: 28), control: CGPoint(x: 20, y: celebrating ? 41 : 38))
        grin.addQuadCurve(to: CGPoint(x: 11, y: 28), control: CGPoint(x: 20, y: 32)); grin.closeSubpath()
        context.fill(grin, with: .color(Color(red: 1, green: 0.82, blue: 0.35)))
        // A tiny connected bat folds its wings above the painted pumpkin.
        let lift = sin(step * 1.1) * 2
        var bat = Path(); bat.move(to: CGPoint(x: 30, y: 6))
        bat.addQuadCurve(to: CGPoint(x: 22, y: 5 - lift), control: CGPoint(x: 25, y: 1 - lift))
        bat.addQuadCurve(to: CGPoint(x: 29, y: 10), control: CGPoint(x: 23, y: 12))
        bat.addLine(to: CGPoint(x: 32, y: 10))
        bat.addQuadCurve(to: CGPoint(x: 39, y: 5 + lift), control: CGPoint(x: 38, y: 12))
        bat.addQuadCurve(to: CGPoint(x: 30, y: 6), control: CGPoint(x: 35, y: 1 + lift)); bat.closeSubpath()
        context.fill(bat, with: .color(Color(red: 0.65, green: 0.48, blue: 0.76)))
        context.fill(Path(ellipseIn: CGRect(x: 29, y: 4, width: 3, height: 7)), with: .color(ink))
    }
    private func snowman(_ context: inout GraphicsContext) {
        let snow = Color(red: 0.94, green: 0.97, blue: 1)
        let red = Color(red: 0.78, green: 0.14, blue: 0.21)
        let ink = Color(red: 0.10, green: 0.19, blue: 0.28)
        let sway = sin(step * 0.9) * 0.5
        let scarf = sin(step * 1.2) * 1.7
        var arms = Path(); arms.move(to: CGPoint(x: 12, y: 25))
        arms.addLine(to: CGPoint(x: 3, y: 19 - sway)); arms.addLine(to: CGPoint(x: 3, y: 16 - sway))
        arms.move(to: CGPoint(x: 29, y: 25)); arms.addLine(to: CGPoint(x: 36, y: 21 + sway))
        context.stroke(arms, with: .color(Color(red: 0.70, green: 0.47, blue: 0.27)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: 9 + sway, y: 18, width: 23, height: 19)), with: .color(snow))
        context.fill(Path(ellipseIn: CGRect(x: 14 + sway, y: 7, width: 15, height: 15)), with: .color(snow))
        var tail = Path(); tail.move(to: CGPoint(x: 25, y: 21))
        tail.addQuadCurve(to: CGPoint(x: 37, y: 21 + scarf), control: CGPoint(x: 31, y: 18))
        tail.addLine(to: CGPoint(x: 35, y: 26 + scarf)); tail.addLine(to: CGPoint(x: 25, y: 25)); tail.closeSubpath()
        context.fill(tail, with: .color(red))
        context.fill(Path(roundedRect: CGRect(x: 13 + sway, y: 20, width: 17, height: 4), cornerRadius: 1), with: .color(red))
        var hat = Path(); hat.move(to: CGPoint(x: 13 + sway, y: 9))
        hat.addQuadCurve(to: CGPoint(x: 25 + sway, y: 1), control: CGPoint(x: 15, y: -1))
        hat.addQuadCurve(to: CGPoint(x: 31 + sway, y: 9), control: CGPoint(x: 31, y: 2)); hat.closeSubpath()
        context.fill(hat, with: .color(red))
        context.fill(Path(roundedRect: CGRect(x: 12 + sway, y: 8, width: 19, height: 3), cornerRadius: 1.5), with: .color(.white))
        context.fill(Path(ellipseIn: CGRect(x: 23 + sway, y: 0, width: 5, height: 5)), with: .color(.white))
        var nose = Path(); nose.move(to: CGPoint(x: 27 + sway, y: 14))
        nose.addLine(to: CGPoint(x: 34 + sway, y: 16)); nose.addLine(to: CGPoint(x: 27 + sway, y: 17)); nose.closeSubpath()
        context.fill(nose, with: .color(Color(red: 0.97, green: 0.65, blue: 0.27)))
        for point in [CGPoint(x: 24 + sway, y: 13), CGPoint(x: 20 + sway, y: 28), CGPoint(x: 20 + sway, y: 32)] {
            context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 1.7, height: 1.7)), with: .color(ink))
        }
        for (index, x) in [15.0, 25].enumerated() {
            let lift = max(0, sin(step * 1.1 + Double(index) * .pi)) * 0.8
            var blade = Path(); blade.move(to: CGPoint(x: x - 3, y: 38 - lift))
            blade.addQuadCurve(to: CGPoint(x: x + 6, y: 37 - lift), control: CGPoint(x: x + 3, y: 40 - lift))
            context.stroke(blade, with: .color(Color(red: 0.74, green: 0.86, blue: 0.96)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
    }
}

private struct RecztActivityTrim: View {
    let style: RecztActivityStyle
    let highlight: Int
    var body: some View {
        Canvas { context, size in
            var cable = Path(); cable.move(to: .zero)
            cable.addQuadCurve(to: CGPoint(x: size.width, y: 0), control: CGPoint(x: size.width / 2, y: 8))
            context.stroke(cable, with: .color(style.snow.opacity(0.3)), lineWidth: 1)
            let colors = style == .halloween ? [style.accent, Color(red: 0.67, green: 0.48, blue: 0.78)] :
                [Color(red: 0.78, green: 0.14, blue: 0.21), Color(red: 0.40, green: 0.74, blue: 0.52), style.accent]
            for index in 0..<7 {
                let fraction = Double(index + 1) / 8
                let x = size.width * fraction, y = 2 + sin(fraction * .pi) * 3
                let color = colors[index % colors.count]
                context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y, width: 4, height: 5)), with: .color(color.opacity(index == highlight ? 1 : 0.58)))
                if index == highlight {
                    var sparkle = Path(); sparkle.move(to: CGPoint(x: x - 4, y: y + 2))
                    sparkle.addLine(to: CGPoint(x: x + 4, y: y + 2))
                    sparkle.move(to: CGPoint(x: x, y: y - 2)); sparkle.addLine(to: CGPoint(x: x, y: y + 6))
                    context.stroke(sparkle, with: .color(color.opacity(0.6)), lineWidth: 0.6)
                }
            }
        }
    }
}

private struct RecztActivityCopy {
    let language: String
    var direction: LayoutDirection { language.hasPrefix("ar") ? .rightToLeft : .leftToRight }
    func text(_ key: String) -> String {
        let base = language.replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init) ?? "en"
        return Self.dictionaries[base]?[key] ?? Self.dictionaries["en"]?[key] ?? "Reczt"
    }
    func headline(_ state: RecztRecognitionAttributes.ContentState) -> String {
        switch state.phase {
        case "found": return text("match_found")
        case "searching": return text("searching")
        case "noMatch": return text("activity_no_match")
        case "denied": return text("mic_denied")
        case "error": return text("activity_error")
        case "cancelled", "idle": return text("activity_ended")
        default: return text("listening")
        }
    }
    func subtitle(_ state: RecztRecognitionAttributes.ContentState) -> String {
        if state.phase == "listening" { return text("activity_listening_hint") }
        if state.phase == "searching" { return text("activity_search_hint") }
        return state.artist
    }
    func seconds(_ count: Int) -> String {
        text("activity_seconds_remaining").replacingOccurrences(of: "{seconds}", with: String(count))
    }
    // BEGIN GENERATED ACTIVITY DICTIONARIES
    static let dictionaries: [String: [String: String]] = [
        "en": [
            "listening": "Listening...",
            "searching": "Searching database...",
            "match_found": "Match Found!",
            "mic_denied": "Microphone permission denied.",
            "activity_no_match": "No match",
            "activity_ended": "Recognition ended",
            "activity_error": "Recognition unavailable",
            "activity_listening_hint": "Sing or hum a song",
            "activity_search_hint": "Matching the melody",
            "activity_seconds_remaining": "{seconds} seconds remaining",
        ],
        "es": [
            "listening": "Escuchando...",
            "searching": "Buscando en la base de datos...",
            "match_found": "¡Coincidencia encontrada!",
            "mic_denied": "Permiso de micrófono denegado.",
            "activity_no_match": "Sin coincidencias",
            "activity_ended": "Reconocimiento finalizado",
            "activity_error": "Reconocimiento no disponible",
            "activity_listening_hint": "Canta o tararea una canción",
            "activity_search_hint": "Buscando la melodía",
            "activity_seconds_remaining": "Quedan {seconds} segundos",
        ],
        "fr": [
            "listening": "Écoute en cours...",
            "searching": "Recherche dans la base de données...",
            "match_found": "Correspondance trouvée !",
            "mic_denied": "Autorisation du microphone refusée.",
            "activity_no_match": "Aucune correspondance",
            "activity_ended": "Reconnaissance terminée",
            "activity_error": "Reconnaissance indisponible",
            "activity_listening_hint": "Chantez ou fredonnez une chanson",
            "activity_search_hint": "Recherche de la mélodie",
            "activity_seconds_remaining": "{seconds} secondes restantes",
        ],
        "de": [
            "listening": "Zuhören...",
            "searching": "Datenbank wird durchsucht...",
            "match_found": "Treffer gefunden!",
            "mic_denied": "Mikrofonberechtigung verweigert.",
            "activity_no_match": "Kein Treffer",
            "activity_ended": "Erkennung beendet",
            "activity_error": "Erkennung nicht verfügbar",
            "activity_listening_hint": "Singe oder summe ein Lied",
            "activity_search_hint": "Melodie wird gesucht",
            "activity_seconds_remaining": "Noch {seconds} Sekunden",
        ],
        "it": [
            "listening": "Ascolto in corso...",
            "searching": "Ricerca nel database...",
            "match_found": "Brano trovato!",
            "mic_denied": "Autorizzazione microfono negata.",
            "activity_no_match": "Nessuna corrispondenza",
            "activity_ended": "Riconoscimento terminato",
            "activity_error": "Riconoscimento non disponibile",
            "activity_listening_hint": "Canta o canticchia una canzone",
            "activity_search_hint": "Ricerca della melodia",
            "activity_seconds_remaining": "{seconds} secondi rimanenti",
        ],
        "pt": [
            "listening": "Ouvindo...",
            "searching": "Buscando no banco de dados...",
            "match_found": "Música encontrada!",
            "mic_denied": "Permissão do microfone negada.",
            "activity_no_match": "Nenhuma correspondência",
            "activity_ended": "Reconhecimento encerrado",
            "activity_error": "Reconhecimento indisponível",
            "activity_listening_hint": "Cante ou cantarole uma música",
            "activity_search_hint": "Buscando a melodia",
            "activity_seconds_remaining": "Restam {seconds} segundos",
        ],
        "ja": [
            "listening": "聞き取り中...",
            "searching": "データベースを検索中...",
            "match_found": "曲が見つかりました！",
            "mic_denied": "マイクのアクセス許可が拒否されました。",
            "activity_no_match": "一致する曲がありません",
            "activity_ended": "認識が終了しました",
            "activity_error": "認識を利用できません",
            "activity_listening_hint": "歌うか、ハミングしてください",
            "activity_search_hint": "メロディーを照合中",
            "activity_seconds_remaining": "残り{seconds}秒",
        ],
        "ko": [
            "listening": "듣는 중...",
            "searching": "데이터베이스 검색 중...",
            "match_found": "곡을 찾았습니다!",
            "mic_denied": "마이크 권한이 거부되었습니다.",
            "activity_no_match": "일치하는 곡이 없어요",
            "activity_ended": "인식이 종료됐어요",
            "activity_error": "인식을 사용할 수 없어요",
            "activity_listening_hint": "노래를 부르거나 흥얼거려 주세요",
            "activity_search_hint": "멜로디를 찾는 중",
            "activity_seconds_remaining": "{seconds}초 남음",
        ],
        "zh": [
            "listening": "正在聆听...",
            "searching": "正在搜索数据库...",
            "match_found": "找到歌曲！",
            "mic_denied": "麦克风权限被拒绝。",
            "activity_no_match": "未找到匹配歌曲",
            "activity_ended": "识别已结束",
            "activity_error": "暂时无法识别",
            "activity_listening_hint": "请唱歌或哼唱",
            "activity_search_hint": "正在匹配旋律",
            "activity_seconds_remaining": "剩余{seconds}秒",
        ],
        "hi": [
            "listening": "सुन रहा है...",
            "searching": "डेटाबेस में खोज रहा है...",
            "match_found": "गाना मिल गया!",
            "mic_denied": "माइक अनुमति अस्वीकृत।",
            "activity_no_match": "कोई मेल नहीं मिला",
            "activity_ended": "पहचान समाप्त हुई",
            "activity_error": "पहचान उपलब्ध नहीं है",
            "activity_listening_hint": "कोई गीत गाएँ या गुनगुनाएँ",
            "activity_search_hint": "धुन का मिलान हो रहा है",
            "activity_seconds_remaining": "{seconds} सेकंड शेष",
        ],
        "ru": [
            "listening": "Слушаю...",
            "searching": "Поиск в базе данных...",
            "match_found": "Песня найдена!",
            "mic_denied": "Доступ к микрофону запрещен.",
            "activity_no_match": "Совпадений нет",
            "activity_ended": "Распознавание завершено",
            "activity_error": "Распознавание недоступно",
            "activity_listening_hint": "Спойте или напойте песню",
            "activity_search_hint": "Ищем мелодию",
            "activity_seconds_remaining": "Осталось секунд: {seconds}",
        ],
        "tr": [
            "listening": "Dinleniyor...",
            "searching": "Veritabanı aranıyor...",
            "match_found": "Eşleşme Bulundu!",
            "mic_denied": "Mikrofon izni reddedildi.",
            "activity_no_match": "Eşleşme yok",
            "activity_ended": "Tanıma sona erdi",
            "activity_error": "Tanıma kullanılamıyor",
            "activity_listening_hint": "Bir şarkı söyleyin veya mırıldanın",
            "activity_search_hint": "Melodi eşleştiriliyor",
            "activity_seconds_remaining": "{seconds} saniye kaldı",
        ],
        "ar": [
            "listening": "جاري الاستماع...",
            "searching": "جاري البحث...",
            "match_found": "تم العثور على الأغنية!",
            "mic_denied": "تم رفض إذن الميكروفون.",
            "activity_no_match": "لا يوجد تطابق",
            "activity_ended": "انتهى التعرف",
            "activity_error": "التعرف غير متاح",
            "activity_listening_hint": "غنِّ أغنية أو دندنها",
            "activity_search_hint": "جارٍ مطابقة اللحن",
            "activity_seconds_remaining": "تبقّى {seconds} ثانية",
        ],
        "nl": [
            "listening": "Luisteren...",
            "searching": "Database zoeken...",
            "match_found": "Nummer Gevonden!",
            "mic_denied": "Microfoontoegang geweigerd.",
            "activity_no_match": "Geen overeenkomst",
            "activity_ended": "Herkenning beëindigd",
            "activity_error": "Herkenning niet beschikbaar",
            "activity_listening_hint": "Zing of neurie een liedje",
            "activity_search_hint": "Melodie wordt gezocht",
            "activity_seconds_remaining": "Nog {seconds} seconden",
        ],
        "pl": [
            "listening": "Słucham...",
            "searching": "Wyszukiwanie w bazie...",
            "match_found": "Znaleziono utwór!",
            "mic_denied": "Odmowa dostępu do mikrofonu.",
            "activity_no_match": "Brak dopasowania",
            "activity_ended": "Rozpoznawanie zakończone",
            "activity_error": "Rozpoznawanie niedostępne",
            "activity_listening_hint": "Zaśpiewaj lub zanuć piosenkę",
            "activity_search_hint": "Dopasowywanie melodii",
            "activity_seconds_remaining": "Pozostało sekund: {seconds}",
        ],
    ]
    // END GENERATED ACTIVITY DICTIONARIES
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
