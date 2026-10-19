//
//  WaitReport.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a wait saw, condition by condition, however it ended.
///
/// A timeout is only useful with the last state of everything that was not
/// met — "timed out" alone sends a caller back to read the whole tree to find
/// out which part was wrong.
public struct WaitReport: Sendable, Equatable {

    /// One condition's account.
    public struct Entry: Sendable, Equatable {

        /// The condition.
        public let condition: WaitCondition

        /// Whether it held, steadily, at the last reading.
        public let met: Bool

        /// Agreeing readings in a row at the end — compare with
        /// ``WaitOptions/stable``.
        public let streak: Int

        /// Readings that looked at it.
        public let readings: Int

        /// Seconds from the start until it was first met, steadily.
        public let metAfter: TimeInterval?

        /// The last reading, `nil` only when none was taken.
        public let last: WaitReading?

        /// An entry from its parts.
        public init(condition: WaitCondition, met: Bool, streak: Int, readings: Int,
                    metAfter: TimeInterval?, last: WaitReading?) {
            self.condition = condition
            self.met = met
            self.streak = streak
            self.readings = readings
            self.metAfter = metAfter
            self.last = last
        }
    }

    /// How it ended.
    public let outcome: WaitOutcome

    /// Every condition, in the order asked.
    public let entries: [Entry]

    /// Seconds from the first reading to the last.
    public let elapsed: TimeInterval

    /// Readings taken.
    public let readings: Int

    /// Readings brought forward by a notification from the app, rather than
    /// taken on the polling schedule.
    public let woken: Int

    /// Whether the app's notifications were being listened to. `false` means
    /// polling alone — the app refused every registration, or it was not
    /// asked.
    public let listened: Bool

    /// A report from its parts.
    public init(outcome: WaitOutcome, entries: [Entry], elapsed: TimeInterval, readings: Int,
                woken: Int, listened: Bool) {
        self.outcome = outcome
        self.entries = entries
        self.elapsed = elapsed
        self.readings = readings
        self.woken = woken
        self.listened = listened
    }
}
