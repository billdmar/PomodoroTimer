//
//  PomodoroWidget.swift
//  PomodoroWidget
//
//  Home- and Lock-screen widget showing the current Pomodoro session. Reads the
//  shared session state the app writes to the App Group suite (SharedSessionState,
//  which must be a member of BOTH the app and widget targets).
//

import WidgetKit
import SwiftUI

struct PomodoroEntry: TimelineEntry {
    let date: Date
    let state: SharedSessionState
}

struct PomodoroProvider: TimelineProvider {
    func placeholder(in context: Context) -> PomodoroEntry {
        PomodoroEntry(date: Date(), state: .idle)
    }

    func getSnapshot(in context: Context, completion: @escaping (PomodoroEntry) -> Void) {
        completion(PomodoroEntry(date: Date(), state: SharedSessionStore().load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroEntry>) -> Void) {
        let state = SharedSessionStore().load()
        let now = Date()

        // While running, refresh at the deadline so the widget flips to "done";
        // otherwise a single static entry until the app writes a new state.
        var entries = [PomodoroEntry(date: now, state: state)]
        if state.isRunning, let end = state.endDate, end > now {
            entries.append(PomodoroEntry(date: end, state: {
                var done = state
                done.isRunning = false
                done.endDate = nil
                done.timeRemaining = 0
                return done
            }()))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PomodoroWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PomodoroEntry

    private var modeLabel: String {
        entry.state.isFocusMode ? "Focus" : "Break"
    }

    private var tint: Color {
        entry.state.isFocusMode
            ? DesignTokens.Palette.focusStart
            : DesignTokens.Palette.breakEnd
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if entry.state.isRunning, let end = entry.state.endDate {
                    // System-rendered live countdown ring on the Lock screen.
                    ProgressView(timerInterval: Date()...end, countsDown: true) {
                        Text(entry.state.emoji)
                    }
                    .progressViewStyle(.circular)
                } else {
                    Text(entry.state.emoji).font(.title2)
                }
            }
        case .accessoryInline:
            if entry.state.isRunning, let end = entry.state.endDate {
                Text("\(entry.state.emoji) \(modeLabel) ends \(end, style: .timer)")
            } else {
                Text("\(entry.state.emoji) Pomodoro")
            }
        default:
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(entry.state.emoji).font(.system(size: 40))
                if entry.state.isRunning, let end = entry.state.endDate {
                    Text(end, style: .timer)
                        .font(.title2).fontWeight(.bold).monospacedDigit()
                        .multilineTextAlignment(.center)
                    Text(modeLabel).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Pomodoro").font(.headline)
                    Text("Tap to focus").font(.caption).foregroundStyle(.secondary)
                }
            }
            .containerBackground(tint.opacity(0.15), for: .widget)
        }
    }
}

struct PomodoroWidget: Widget {
    let kind = "PomodoroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomodoroProvider()) { entry in
            PomodoroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pomodoro")
        .description("See your current focus or break session at a glance.")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}
