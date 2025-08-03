//
//  pomadoro2App.swift
//  pomadoro2
//
//  Created by Bill Mar on 7/30/25.
//

import SwiftUI
import Firebase

@main
struct pomadoro2App: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
