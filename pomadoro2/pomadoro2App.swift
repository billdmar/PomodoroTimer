//
//  pomadoro2App.swift
//  pomadoro2
//
//  Created by Bill Mar on 7/30/25.
//

import SwiftUI
import Firebase
import UIKit
import UserNotifications

/// Configures Firebase and notification handling at launch.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        // Handle interactive notification actions (e.g. "Extend +5 min").
        UNUserNotificationCenter.current().delegate = NotificationActionHandler.shared
        NotificationActions.registerCategories()
        return true
    }
}

@main
struct pomadoro2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
