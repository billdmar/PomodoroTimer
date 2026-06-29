//
//  LiveActivityController.swift
//  pomadoro2
//
//  Starts / updates / ends the Pomodoro Live Activity. All ActivityKit calls
//  are gated on iOS 16.1+ and on Live Activities being enabled, so this is a
//  safe no-op on older OSes or when the user has them turned off. Updates here
//  are local (app-driven); remote push updates are out of scope.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
final class LiveActivityController {
    private var activity: Activity<TimerActivityAttributes>?

    /// Begins a Live Activity for a running session ending at `endDate`.
    func start(endDate: Date, isFocusMode: Bool, emoji: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Replace any stale activity first.
        end()

        let attributes = TimerActivityAttributes(sessionName: "Pomodoro")
        let state = TimerActivityAttributes.ContentState(
            endDate: endDate, isFocusMode: isFocusMode, emoji: emoji
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endDate)
            )
        } catch {
            Log.debug("Live Activity start error: \(error)")
        }
    }

    func update(endDate: Date, isFocusMode: Bool, emoji: String) {
        guard let activity else { return }
        let state = TimerActivityAttributes.ContentState(
            endDate: endDate, isFocusMode: isFocusMode, emoji: emoji
        )
        Task { await activity.update(.init(state: state, staleDate: endDate)) }
    }

    func end() {
        guard let activity else { return }
        let current = activity
        self.activity = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }
}
