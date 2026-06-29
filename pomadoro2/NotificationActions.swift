//
//  NotificationActions.swift
//  pomadoro2
//
//  Defines the interactive completion-notification action ("Extend +5 min") and
//  a UNUserNotificationCenterDelegate that bridges a tap on it back to the app
//  via NotificationCenter, where TimerManager picks it up and extends the
//  session. Kept separate so TimerManager doesn't need to be a UN delegate.
//

import Foundation
import UserNotifications

enum NotificationActions {
    static let completionCategoryID = "TIMER_COMPLETION"
    static let extendActionID = "EXTEND_5"

    /// In-process notification posted when the user taps "Extend +5 min".
    static let extendRequested = Notification.Name("pomodoro.extendRequested")

    /// Registers the completion category + its action. Call once at launch.
    static func registerCategories() {
        let extend = UNNotificationAction(
            identifier: extendActionID,
            title: "Extend +5 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: completionCategoryID,
            actions: [extend],
            intentIdentifiers: [],
            options: []
        )
        // Merge with any categories other components registered.
        UNUserNotificationCenter.current().getNotificationCategories { existing in
            var merged = existing
            merged.insert(category)
            UNUserNotificationCenter.current().setNotificationCategories(merged)
        }
    }
}

/// Receives notification taps and forwards the extend action into the app.
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == NotificationActions.extendActionID {
            NotificationCenter.default.post(name: NotificationActions.extendRequested, object: nil)
        }
        completionHandler()
    }

    /// Show the banner even when the app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
