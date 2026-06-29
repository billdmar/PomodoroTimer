//
//  pomadoro2App.swift
//  pomadoro2
//
//  Created by Bill Mar on 7/30/25.
//

import SwiftUI
import Firebase
import UIKit

// Add AppDelegate class to properly conform to UIApplicationDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct pomadoro2App: App {
    // Register the AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
