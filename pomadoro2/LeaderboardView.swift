//
//  LeaderboardView.swift
//  pomadoro2
//
//  Simple version to avoid compilation errors
//

import SwiftUI

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("🏆")
                    .font(.system(size: 80))
                
                Text("Leaderboard")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Coming Soon!")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("We're setting up CloudKit to share your Pomodoro achievements with other users.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.top, 50)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
