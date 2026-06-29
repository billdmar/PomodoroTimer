//
//  AchievementOverlay.swift
//  pomadoro2
//
//  A celebratory overlay shown when a focus session newly unlocks an
//  achievement. Tapping anywhere (or "Nice!") dismisses it.
//

import SwiftUI

struct AchievementOverlay: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: DesignTokens.Spacing.lg) {
                Text("Achievement Unlocked! 🏆")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(achievement.icon)
                    .font(.system(size: DesignTokens.Typography.displaySize))
                    .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.4))
                    .rotationEffect(.degrees(reduceMotion ? 0 : (appeared ? 0 : -20)))

                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text(achievement.title)
                        .font(DesignTokens.Typography.screenTitle)
                        .multilineTextAlignment(.center)
                    Text(achievement.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Button("Nice!", action: onDismiss)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(Capsule().fill(Color.accentColor))
            }
            .padding(DesignTokens.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.section)
                    .fill(Color(.systemBackground))
                    .shadow(color: DesignTokens.Shadow.cardColor,
                            radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
            )
            .padding(DesignTokens.Spacing.xl)
            .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.8))
            .opacity(appeared ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement unlocked: \(achievement.title). \(achievement.subtitle)")
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
    }
}
