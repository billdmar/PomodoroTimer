//
//  TimerComponents.swift
//  pomadoro2
//
//  Small, reusable UI components used by the timer screens. Extracted from
//  ContentView to keep that file focused on layout/state orchestration.
//

import SwiftUI

/// A compact stat tile (icon + value + label), used in the main timer header.
struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        // Read as a single element, e.g. "Today's Focus: 25".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

/// A circular icon button used for the main timer controls.
struct ControlButton: View {
    let icon: String
    let action: () -> Void
    let disabled: Bool
    let color: Color
    var accessibilityLabel: String = ""

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(disabled ? .gray : .white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(disabled ? Color.gray.opacity(0.3) : color)
                        .shadow(color: disabled ? .clear : color.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .disabled(disabled)
        .scaleEffect(disabled ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: disabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A frosted-glass action button used over the full-screen timer.
struct FloatingButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 80, height: 60)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.section)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.section)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
