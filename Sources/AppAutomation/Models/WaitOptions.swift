//
//  WaitOptions.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How long to wait, how often to look, and how sure to be.
public struct WaitOptions: Sendable, Equatable {

    /// Give up after this many seconds. A reading is always taken at the
    /// deadline, so something that arrives just in time is seen.
    public var timeout: TimeInterval

    /// Seconds between readings when nothing is heard from the app.
    public var interval: TimeInterval

    /// How many readings in a row, each at least ``interval`` after the last
    /// one counted, must agree before a condition counts as met.
    ///
    /// Two by default: a button that appears for one frame and goes again,
    /// or a value that passes through the wanted text on the way to another,
    /// is a flicker, not an answer.
    public var stable: Int

    /// Whether to listen for Accessibility notifications, which bring a
    /// reading forward the moment the app reports a change. Polling at
    /// ``interval`` happens either way.
    public var listens: Bool

    /// Options, defaulting to ``standard``'s.
    public init(timeout: TimeInterval = 10, interval: TimeInterval = 0.2, stable: Int = 2, listens: Bool = true) {
        self.timeout = timeout
        self.interval = interval
        self.stable = stable
        self.listens = listens
    }

    /// Ten seconds, a reading every 0.2 s, two in a row to agree.
    public static let standard = WaitOptions()
}
