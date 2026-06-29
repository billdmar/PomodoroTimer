//
//  LeaderboardView.swift
//  pomadoro2
//
//  Firebase-powered leaderboard
//

import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var firebaseManager: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var leaderboardEntries: [LeaderboardEntry] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !firebaseManager.isAuthenticated {
                    // Authentication required view
                    VStack(spacing: DesignTokens.Spacing.xxl) {
                        Text("🔐")
                            .font(.system(size: DesignTokens.Typography.displaySize))
                            .accessibilityHidden(true)

                        Text("Join the Community!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Sign in to see how you compare with other Pomodoro masters around the world.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            firebaseManager.signInAnonymously(userInitiated: true)
                        }) {
                            HStack {
                                if firebaseManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                }
                                Text(firebaseManager.isLoading ? "Joining..." : "Join Anonymously")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                                    .fill(Color.blue)
                            )
                        }
                        .disabled(firebaseManager.isLoading)
                        .padding(.horizontal, 40)

                        if let errorMessage = firebaseManager.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        Spacer()
                    }
                    .padding(.top, 50)
                } else {
                    // Leaderboard content
                    if isLoading {
                        VStack(spacing: DesignTokens.Spacing.lg) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading leaderboard...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: DesignTokens.Spacing.lg) {
                                // Header
                                VStack(spacing: DesignTokens.Spacing.md) {
                                    Text("🏆")
                                        .font(.system(size: DesignTokens.Typography.emojiSize))
                                        .accessibilityHidden(true)

                                    Text("Global Leaderboard")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)

                                    Text("Top Pomodoro Masters")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, DesignTokens.Spacing.xxl)
                                .padding(.bottom, 10)

                                // Leaderboard entries
                                LazyVStack(spacing: DesignTokens.Spacing.sm) {
                                    ForEach(Array(leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                                        LeaderboardRow(
                                            rank: index + 1,
                                            entry: entry,
                                            isCurrentUser: entry.userId == firebaseManager.currentUser?.uid
                                        )
                                    }
                                }
                                .padding(.horizontal, DesignTokens.Spacing.lg)

                                if leaderboardEntries.isEmpty {
                                    VStack(spacing: DesignTokens.Spacing.md) {
                                        Text("🌱")
                                            .font(.system(size: 40))
                                            .accessibilityHidden(true)

                                        Text("Be the first!")
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text("Complete a focus session to appear on the leaderboard.")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.top, 40)
                                    .padding(.horizontal, 40)
                                }

                                Spacer(minLength: 50)
                            }
                        }
                        .refreshable {
                            loadLeaderboard()
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if firebaseManager.isAuthenticated && !isLoading {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            loadLeaderboard()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .onAppear {
            if firebaseManager.isAuthenticated {
                loadLeaderboard()
            }
        }
        .onChange(of: firebaseManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                loadLeaderboard()
            }
        }
    }

    private func loadLeaderboard() {
        isLoading = true
        firebaseManager.getLeaderboard { entries in
            self.leaderboardEntries = entries
            self.isLoading = false
        }
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }

    private var rankEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "🏅"
        }
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                if rank <= 3 {
                    Text(rankEmoji)
                        .font(.title3)
                } else {
                    Text("\(rank)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(rankColor)
                }
            }

            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .fontWeight(isCurrentUser ? .bold : .medium)

                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }

                HStack(spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.formattedMinutes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "flame")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(entry.streak) day streak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            // Total minutes display
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.formattedMinutes)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)

                Text("focus time")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                .fill(isCurrentUser ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                        .stroke(isCurrentUser ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank): \(entry.displayName), \(entry.totalMinutes) minutes, \(entry.streak) day streak\(isCurrentUser ? ", you" : "")")
    }
}
