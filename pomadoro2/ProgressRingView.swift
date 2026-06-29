//
//  ProgressRingView.swift
//  pomadoro2
//
//  The 260pt circular timer ring (glow + track + gradient progress stroke +
//  centered time/mode label). Extracted from ContentView's main timer screen so
//  the ring is reusable and ContentView stays focused on orchestration.
//

import SwiftUI

struct ProgressRingView: View {
    let isFocusMode: Bool
    let progress: Double
    let formattedTime: String
    var scaleEffect: CGFloat = 1.0
    var contentOpacity: Double = 1.0

    private var ringColors: [Color] {
        isFocusMode
            ? [Color.red.opacity(0.7), Color.red, Color.orange.opacity(0.8)]
            : [Color.green.opacity(0.7), Color.green, Color.mint.opacity(0.8)]
    }

    var body: some View {
        ZStack {
            // Outer glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (isFocusMode ? Color.red : Color.green).opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 100,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .scaleEffect(scaleEffect)
                .animation(.easeInOut(duration: DesignTokens.Animation.standard), value: scaleEffect)

            // Background circle with subtle shadow
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 260, height: 260)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .scaleEffect(scaleEffect)
                .animation(.easeInOut(duration: DesignTokens.Animation.standard), value: scaleEffect)

            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: ringColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-90))
                .scaleEffect(scaleEffect)
                .animation(.easeInOut(duration: DesignTokens.Animation.smooth), value: progress)
                .animation(.easeInOut(duration: DesignTokens.Animation.standard), value: scaleEffect)

            // Time display
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(formattedTime)
                    .font(DesignTokens.Typography.timerCompact)
                    .foregroundColor(.primary)
                    .opacity(contentOpacity)
                    .animation(.easeInOut(duration: DesignTokens.Animation.standard), value: contentOpacity)

                Text(isFocusMode ? "Focus" : "Break")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
                    .opacity(contentOpacity)
                    .animation(.easeInOut(duration: DesignTokens.Animation.standard), value: contentOpacity)
            }
        }
    }
}
