//
//  PomodoroLiveActivity.swift
//  PomodoroWidget
//
//  Live Activity UI for the Lock screen and Dynamic Island. Driven by
//  TimerActivityAttributes (a member of both targets). Dynamic Island only
//  renders on physical devices that have it.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Lock-screen / banner presentation.
            lockScreenView(context.state)
                .padding()
                .activityBackgroundTint(tint(context.state).opacity(0.18))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.emoji).font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(modeLabel(context.state))
                        .font(.caption).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.endDate, style: .timer)
                        .font(.title2).fontWeight(.bold).monospacedDigit()
                        .multilineTextAlignment(.center)
                }
            } compactLeading: {
                Text(context.state.emoji)
            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "pomodoro://timer"))
        }
    }

    private func lockScreenView(_ state: TimerActivityAttributes.ContentState) -> some View {
        HStack(spacing: 12) {
            Text(state.emoji).font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text(modeLabel(state)).font(.caption).foregroundStyle(.secondary)
                Text(state.endDate, style: .timer)
                    .font(.title).fontWeight(.bold).monospacedDigit()
            }
            Spacer()
        }
    }

    private func modeLabel(_ state: TimerActivityAttributes.ContentState) -> String {
        state.isFocusMode ? "Focus" : "Break"
    }

    private func tint(_ state: TimerActivityAttributes.ContentState) -> Color {
        state.isFocusMode
            ? DesignTokens.Palette.focusStart
            : DesignTokens.Palette.breakEnd
    }
}
