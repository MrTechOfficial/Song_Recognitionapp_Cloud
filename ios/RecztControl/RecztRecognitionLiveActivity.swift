import ActivityKit
import SwiftUI
import WidgetKit

struct RecztRecognitionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecztRecognitionAttributes.self) { context in
            HStack(spacing: 12) {
                statusIcon(for: context.state)
                    .font(.title2)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if context.state.phase == "listening" && context.state.secondsRemaining > 0 {
                    Text("\(context.state.secondsRemaining)s")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    statusIcon(for: context.state)
                        .font(.title2)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.phase == "listening" && context.state.secondsRemaining > 0 {
                        Text("\(context.state.secondsRemaining)s")
                            .font(.headline)
                            .monospacedDigit()
                    } else if context.state.phase == "found" {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(expandedTitle(for: context.state))
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 3) {
                        Text(context.state.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                statusIcon(for: context.state)
                    .font(.caption.weight(.bold))
            } compactTrailing: {
                if context.state.phase == "listening" && context.state.secondsRemaining > 0 {
                    Text("\(context.state.secondsRemaining)")
                        .font(.caption2.monospacedDigit())
                } else if context.state.phase == "found" {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "waveform")
                }
            } minimal: {
                statusIcon(for: context.state)
                    .font(.caption2)
            }
            .keylineTint(.orange)
        }
    }

    @ViewBuilder
    private func statusIcon(for state: RecztRecognitionAttributes.ContentState) -> some View {
        switch state.phase {
        case "found":
            Image(systemName: "music.note")
                .foregroundStyle(.orange)
        case "searching":
            Image(systemName: "waveform.badge.magnifyingglass")
                .foregroundStyle(.purple)
        case "noMatch", "error", "denied":
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        default:
            Image(systemName: "waveform.badge.mic")
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)
        }
    }

    private func expandedTitle(for state: RecztRecognitionAttributes.ContentState) -> String {
        switch state.phase {
        case "found": return "Song found"
        case "searching": return "Finding your song"
        case "noMatch": return "No match"
        case "denied": return "Microphone access needed"
        default: return "Reczt is listening"
        }
    }
}
