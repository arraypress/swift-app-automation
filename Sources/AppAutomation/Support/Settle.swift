//
//  Settle.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Waiting a moment for another app to catch up — and no longer.
//

import Foundation

/// Polling for a change that another process makes in its own time.
///
/// A value set through Accessibility is not always readable the instant the
/// call returns. Measured in Chrome: `AXUIElementSetAttributeValue` returned
/// success, an immediate read-back said `nil`, and the value appeared **30 ms**
/// later. A check that reads once calls that a failure; one that waits
/// forever hangs on a field that really did refuse.
enum Settle {

    /// How long to wait for a change before calling it refused.
    ///
    /// Sixteen times the 30 ms measured in Chrome. Long enough for a busy
    /// renderer, short enough that a refusal is reported before anybody
    /// wonders whether the tool has hung.
    static let timeout: TimeInterval = 0.5

    /// How often to look.
    static let interval: TimeInterval = 0.025

    /// Waits until `condition` is true or `timeout` passes.
    ///
    /// - Parameter sleep: Injected so tests cost no wall-clock.
    /// - Returns: Whether the condition came true.
    static func until(
        timeout: TimeInterval = Settle.timeout,
        interval: TimeInterval = Settle.interval,
        sleep: (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) },
        _ condition: () -> Bool
    ) -> Bool {
        var waited: TimeInterval = 0
        while true {
            if condition() { return true }
            guard waited < timeout else { return false }
            sleep(interval)
            waited += interval
        }
    }
}
