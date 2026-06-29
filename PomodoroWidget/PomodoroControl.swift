//
//  PomodoroControl.swift
//  PomodoroWidget
//
//  iOS 18 Control Center control: a one-tap "Start Focus" button. It runs an
//  App Intent that drops a command in the shared mailbox and opens the app,
//  which starts the session. Requires the App Group shared with the app.
//
//  Add this control's `@main`-less widget to the bundle (PomodoroWidgetBundle)
//  once the widget target exists — see docs/WIDGET_SETUP.md.
//

import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
struct PomodoroControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.billdmar.pomadoro2.startfocus") {
            ControlWidgetButton(action: StartFocusSessionIntent()) {
                Label("Start Focus", systemImage: "timer")
            }
        }
        .displayName("Start Focus")
        .description("Begin a Pomodoro focus session.")
    }
}
