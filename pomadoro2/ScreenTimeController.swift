//
//  ScreenTimeController.swift
//  pomadoro2
//
//  Real app-blocking via Apple's Screen Time frameworks (FamilyControls /
//  ManagedSettings), replacing the previous notification-only "lock" which
//  couldn't actually stop the user leaving.
//
//  IMPORTANT — entitlement gating:
//  These frameworks COMPILE and LINK without any entitlement; the
//  `com.apple.developer.family-controls` entitlement is only checked at RUNTIME
//  when authorization is requested. So CI (CODE_SIGNING_ALLOWED=NO, no
//  entitlement) builds fine, and on a device without the (Apple-approval-gated)
//  entitlement, authorization simply fails and the app degrades gracefully to
//  the existing motivational behavior. Request the entitlement from Apple to
//  enable real shielding.
//

import Foundation

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

/// Abstracts real shielding so AppLockManager can depend on a protocol and fall
/// back to a no-op when Screen Time isn't available/authorized.
protocol ScreenTimeControlling {
    /// Whether the user has granted Family Controls authorization.
    var isAuthorized: Bool { get }
    /// Requests authorization; safe to call repeatedly. Throws/sets false when
    /// the entitlement is absent or the user declines.
    func requestAuthorization() async -> Bool
    /// Applies the configured app shields (effective only when authorized).
    func startShielding()
    /// Removes all shields.
    func stopShielding()
}

/// Used when FamilyControls is unavailable or unauthorized — does nothing, so
/// the app keeps working with its motivational nudges only.
struct NoopScreenTimeController: ScreenTimeControlling {
    var isAuthorized: Bool { false }
    func requestAuthorization() async -> Bool { false }
    func startShielding() {}
    func stopShielding() {}
}

#if canImport(FamilyControls)
/// Real implementation backed by FamilyControls + ManagedSettings.
@available(iOS 16.0, *)
final class FamilyControlsScreenTimeController: ScreenTimeControlling {
    // Created lazily: instantiating a ManagedSettingsStore eagerly at app launch
    // (before/without the family-controls entitlement) can trap, so we defer it
    // until shielding is actually applied under an authorized session.
    private lazy var store = ManagedSettingsStore()
    private(set) var isAuthorized = false

    /// The apps/categories the user chose to block (set via FamilyActivityPicker
    /// in the UI). Persisted selection is out of scope here; an empty selection
    /// shields nothing until the user picks. Lazy for the same launch-safety
    /// reason as `store`.
    lazy var selection = FamilyActivitySelection()

    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            // Most commonly: the family-controls entitlement isn't present.
            Log.debug("Screen Time authorization failed: \(error)")
            isAuthorized = false
        }
        return isAuthorized
    }

    func startShielding() {
        guard isAuthorized else { return }
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    func stopShielding() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
#endif

/// Returns the best available controller for this build/OS.
enum ScreenTimeControllerFactory {
    static func make() -> ScreenTimeControlling {
        #if canImport(FamilyControls)
        if #available(iOS 16.0, *) {
            return FamilyControlsScreenTimeController()
        }
        #endif
        return NoopScreenTimeController()
    }
}
