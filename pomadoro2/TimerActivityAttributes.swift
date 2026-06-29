//
//  TimerActivityAttributes.swift
//  pomadoro2
//
//  Shared ActivityKit attributes for the Pomodoro Live Activity. Must be a
//  member of BOTH the app target (which starts/updates/ends the activity) and
//  the widget target (which renders it). See docs/WIDGET_SETUP.md.
//

import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    /// Dynamic values updated while the activity is live.
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var isFocusMode: Bool
        var emoji: String
    }

    /// Static for the life of the activity.
    var sessionName: String
}
