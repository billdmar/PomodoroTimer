//
//  CardModifiers.swift
//  pomadoro2
//
//  The "card" surface — a rounded rectangle with a fill and a soft shadow — was
//  duplicated ~10 times across StatsView, SettingsView and LeaderboardView with
//  slightly different radii and shadow values. This modifier defines it once,
//  using the design tokens, so every card matches and a restyle is one edit.
//

import SwiftUI

private struct CardStyle: ViewModifier {
    var fill: Color = Color(.systemBackground)
    var radius: CGFloat = DesignTokens.CornerRadius.card

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius)
                .fill(fill)
                .shadow(
                    color: DesignTokens.Shadow.cardColor,
                    radius: DesignTokens.Shadow.cardRadius,
                    x: 0,
                    y: DesignTokens.Shadow.cardY
                )
        )
    }
}

extension View {
    /// Applies the standard card surface (rounded fill + soft shadow).
    func cardStyle(
        fill: Color = Color(.systemBackground),
        radius: CGFloat = DesignTokens.CornerRadius.card
    ) -> some View {
        modifier(CardStyle(fill: fill, radius: radius))
    }
}
