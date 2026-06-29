//
//  DynamicBackgroundView.swift
//  pomadoro2
//
//  The animated, mode-tinted gradient shown behind a running session. Extracted
//  from ContentView so that file focuses on layout/state orchestration. Driven
//  by `colorShift` (advanced on a timer in ContentView) for a slow drift.
//

import SwiftUI

struct DynamicBackgroundView: View {
    let isFocusMode: Bool
    let colorShift: CGFloat

    var body: some View {
        let colors = DesignTokens.gradientColors(isFocusMode: isFocusMode)
        return ZStack {
            // Base gradient for the current mode.
            LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()

            // Shifting overlay that moves the gradient around.
            LinearGradient(
                gradient: Gradient(colors: colors.map { $0.opacity(0.8) }),
                startPoint: UnitPoint(
                    x: 0.0 + sin(Double(colorShift) * 0.01) * 0.5,
                    y: 0.0 + cos(Double(colorShift) * 0.008) * 0.3
                ),
                endPoint: UnitPoint(
                    x: 1.0 + cos(Double(colorShift) * 0.012) * 0.5,
                    y: 1.0 + sin(Double(colorShift) * 0.009) * 0.3
                )
            )
            .ignoresSafeArea()
            .blendMode(.overlay)

            // Second shifting layer for more movement.
            RadialGradient(
                gradient: Gradient(colors: [
                    colors[0].opacity(0.3),
                    Color.clear,
                    colors[1].opacity(0.3)
                ]),
                center: UnitPoint(
                    x: 0.5 + sin(Double(colorShift) * 0.006) * 0.4,
                    y: 0.5 + cos(Double(colorShift) * 0.007) * 0.4
                ),
                startRadius: 100 + sin(Double(colorShift) * 0.015) * 50,
                endRadius: 600 + cos(Double(colorShift) * 0.011) * 200
            )
            .ignoresSafeArea()
            .blendMode(.multiply)
        }
        .animation(.easeInOut(duration: DesignTokens.Animation.elevated), value: isFocusMode)
    }
}
