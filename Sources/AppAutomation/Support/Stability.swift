//
//  Stability.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Counting agreeing readings, so a flicker is not an answer.
//

import Foundation

/// One condition's run of agreeing readings.
///
/// A condition is met when ``required`` readings in a row satisfy it AND are
/// identical. Identical, not merely satisfying: `--value-contains 4` against
/// a counter going 14, 24, 34 is satisfied every time and settled never.
///
/// **A reading can break a run early, but only extend it on time.** A
/// notification from the app brings a reading forward, so a change is seen
/// at once; a reading taken sooner than ``spacing`` after the last one that
/// counted does not add to the run. Otherwise two readings taken 5 ms apart
/// during a burst of notifications would confirm a button that was on screen
/// for 30 ms — the exact flicker this exists to refuse.
struct Stability {

    /// Agreeing readings needed.
    let required: Int

    /// The least time between two readings that both count.
    let spacing: TimeInterval

    /// Agreeing, satisfying readings in a row, as of the last reading.
    private(set) var streak = 0

    /// Readings recorded.
    private(set) var readings = 0

    /// The last reading recorded.
    private(set) var last: WaitReading?

    /// When the run that is now met became met.
    private(set) var metAfter: TimeInterval?

    /// When the last reading that counted was taken.
    private var countedAt: TimeInterval?

    init(required: Int, spacing: TimeInterval) {
        self.required = max(required, 1)
        self.spacing = spacing
    }

    /// Whether the condition is met as of the last reading.
    var isMet: Bool { streak >= required }

    /// Records a reading taken `at` seconds from the start.
    mutating func record(_ reading: WaitReading, satisfied: Bool, at time: TimeInterval) {
        readings += 1
        defer { last = reading }

        guard satisfied else {
            streak = 0
            countedAt = nil
            metAfter = nil
            return
        }
        if reading == last, streak > 0, let countedAt {
            // The same answer again: it counts only once enough time has
            // passed for it to be a second look rather than the same moment.
            guard time - countedAt >= spacing else { return }
            streak += 1
            self.countedAt = time
        } else {
            streak = 1
            countedAt = time
            metAfter = nil
        }
        if streak == required { metAfter = time }
    }
}
