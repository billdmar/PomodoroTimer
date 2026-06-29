//
//  SessionEngine.swift
//  pomadoro2
//
//  The countdown clock, extracted from TimerManager. It owns the TimerState
//  machine and the UI-refresh tick, and reports back via two callbacks — but it
//  knows nothing about Firebase, notifications, stats, or the app lock. That
//  separation keeps the safety-critical timing logic small and independently
//  testable, while TimerManager handles orchestration.
//
//  The wall clock is the source of truth: a running state carries its `endDate`
//  and `remaining` is always derived, so the countdown is immune to background
//  suspension and tick drift. The tick only drives UI refresh.
//

import Foundation

@MainActor
final class SessionEngine {

    private(set) var state: TimerState
    private var tickTask: Task<Void, Never>?

    /// Called on each tick (and on recompute) with the current remaining time.
    var onTick: ((TimeInterval) -> Void)?
    /// Called once when a running session reaches its deadline. The engine has
    /// already stopped ticking and left the running state before this fires.
    var onFinished: (() -> Void)?

    init(initialRemaining: TimeInterval) {
        state = .idle(remaining: initialRemaining)
    }

    deinit {
        tickTask?.cancel()
    }

    // MARK: - Derived reads

    var isRunning: Bool { state.isRunning }
    var endDate: Date? { state.endDate }
    func remaining(now: Date = Date()) -> TimeInterval { state.remaining(now: now) }

    // MARK: - Transitions

    /// Starts counting down `duration` seconds from now and begins ticking.
    /// Returns the anchored deadline (for notifications / Live Activity).
    @discardableResult
    func start(duration: TimeInterval) -> Date {
        let endDate = Date().addingTimeInterval(duration)
        state = .running(endDate: endDate)
        startTick()
        return endDate
    }

    /// Freezes the running session at its current remaining time. Computed
    /// directly (not via recompute) so pausing never triggers completion —
    /// completion flows only through the tick path, avoiding a pause↔finish
    /// recursion.
    func pause() {
        if state.isRunning {
            state = .paused(remaining: state.remaining(now: Date()))
        }
        stopTick()
    }

    /// Stops ticking and returns to an idle state at `remaining`.
    func reset(to remaining: TimeInterval) {
        stopTick()
        state = .idle(remaining: remaining)
    }

    /// Restores a recovered session as paused (the user resumes explicitly).
    func restorePaused(remaining: TimeInterval) {
        stopTick()
        state = .paused(remaining: remaining)
    }

    /// Adds `seconds` to whatever state we're in. When running, re-anchors the
    /// deadline and returns it (so the caller can reschedule notifications);
    /// otherwise returns nil.
    @discardableResult
    func extend(by seconds: TimeInterval) -> Date? {
        switch state {
        case .running:
            let newEnd = Date().addingTimeInterval(state.remaining(now: Date()) + seconds)
            state = .running(endDate: newEnd)
            return newEnd
        case let .paused(remaining):
            state = .paused(remaining: remaining + seconds)
            return nil
        case let .idle(remaining):
            state = .idle(remaining: remaining + seconds)
            return nil
        }
    }

    // MARK: - Tick & completion

    /// Recomputes remaining from the wall clock and fires completion once the
    /// deadline passes. Safe to call on foreground/recovery — it shares the one
    /// completion path with the tick.
    func recompute() {
        guard state.isRunning else { return }
        if state.hasCompleted(now: Date()) {
            // Stop and leave the running state BEFORE notifying, so the callback
            // can transition us without re-entering completion.
            stopTick()
            state = .paused(remaining: 0)
            onTick?(0)
            onFinished?()
        } else {
            onTick?(state.remaining(now: Date()))
        }
    }

    private func startTick() {
        stopTick()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.state.isRunning else { return }
                self.recompute()
                try? await Task.sleep(nanoseconds: UInt64(TimerConstants.tickInterval * 1_000_000_000))
            }
        }
    }

    private func stopTick() {
        tickTask?.cancel()
        tickTask = nil
    }
}
