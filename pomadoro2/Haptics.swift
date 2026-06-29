//
//  Haptics.swift
//  pomadoro2
//
//  Thin wrapper over UIKit feedback generators so timer events have tactile
//  feedback. Centralized here (rather than scattering generator instances) so
//  the feedback vocabulary stays consistent and is a no-op on devices without
//  a Taptic Engine.
//

import UIKit

enum Haptics {
    /// Light tap — minor control actions (reset, skip).
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium tap — starting a session.
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Success notification — a session completed.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
