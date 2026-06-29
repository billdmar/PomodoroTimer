//
//  DesignTokens.swift
//  pomadoro2
//
//  Centralized design system. Colors, spacing, corner radii and animation
//  timings were previously hardcoded inline across the views (the focus/break
//  gradient RGB tuples alone were repeated six times in ContentView). Defining
//  them once keeps the look consistent and makes a restyle a one-file change.
//

import SwiftUI

enum DesignTokens {

    // MARK: - Brand colors

    enum Palette {
        /// Focus-mode gradient (coral → peach).
        static let focusStart = Color(red: 1.0, green: 0.373, blue: 0.427) // #FF5F6D
        static let focusEnd = Color(red: 1.0, green: 0.765, blue: 0.443)   // #FFC371

        /// Break-mode gradient (deep blue → cyan).
        static let breakStart = Color(red: 0.2, green: 0.3, blue: 0.8)
        static let breakEnd = Color(red: 0.0, green: 0.8, blue: 1.0)
    }

    /// The two-stop gradient colors for the given mode.
    static func gradientColors(isFocusMode: Bool) -> [Color] {
        isFocusMode
            ? [Palette.focusStart, Palette.focusEnd]
            : [Palette.breakStart, Palette.breakEnd]
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 30
    }

    // MARK: - Corner radius

    enum CornerRadius {
        static let card: CGFloat = 12
        static let section: CGFloat = 16
    }

    // MARK: - Animation

    enum Animation {
        static let standard: TimeInterval = 0.3
        static let smooth: TimeInterval = 0.5
        static let emphasis: TimeInterval = 0.6
    }
}
