//
//  WaitLoop.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Reading until every condition holds, or time runs out.
//

import Foundation

/// The time a wait runs on: the clock, and a pause that a notification from
/// the app can cut short.
///
/// Injected, so the loop runs against a fake app on a fake clock in tests and
/// costs no wall-clock.
struct WaitClock {

    /// Seconds, monotonic.
    let now: () -> TimeInterval

    /// Waits up to this many seconds. Returns `true` when the app reported a
    /// change before they were up, `false` when they simply passed.
    let pause: (TimeInterval) -> Bool
}

/// The loop behind ``AppSession/wait(until:options:)``.
///
/// Read, judge every condition, stop when all of them have held steadily at
/// the same reading or the timeout has passed — otherwise wait for the next
/// poll, or for the app to say something changed, whichever comes first.
enum WaitLoop {

    /// How far under ``WaitOptions/interval`` two readings may be and both
    /// still count toward a run. A timer firing a millisecond early is still
    /// on schedule.
    static let spacingTolerance = 0.9

    /// How long to let a burst of notifications land before reading.
    ///
    /// Measured on TextEdit: opening a window sent its notifications over
    /// 12 ms, closing one sent fourteen over 25 ms. Reading on the first of
    /// them reads a window half-built.
    static let coalesce: TimeInterval = 0.025

    /// The least time between any two readings, however chatty the app is.
    /// A web page relaying out continuously would otherwise be read back to
    /// back for the whole timeout.
    static let minimumGap: TimeInterval = 0.05

    /// Runs a wait.
    ///
    /// - Parameters:
    ///   - listening: Whether `clock.pause` can be woken by the app, asked
    ///     when the report is written — recorded on it, nothing more.
    ///   - read: One observation per subject, in order. Throwing stops the
    ///     wait: the grant went, the screen locked, the app quit.
    static func run(
        _ conditions: [WaitCondition],
        options: WaitOptions,
        listening: () -> Bool,
        clock: WaitClock,
        read: ([WaitSubject]) throws -> [WaitObservation]
    ) -> WaitReport {
        // Each subject is read once per reading, however many conditions
        // look at it.
        var subjects: [WaitSubject] = []
        for condition in conditions where !subjects.contains(condition.subject) {
            subjects.append(condition.subject)
        }
        let lookups = conditions.map { condition in subjects.firstIndex(of: condition.subject) ?? 0 }

        let spacing = options.interval * spacingTolerance
        var trackers = conditions.map { _ in Stability(required: options.stable, spacing: spacing) }
        let start = clock.now()
        // Compared directly, never as `now - start >= timeout`: in floating
        // point the reading taken AT the deadline can come out a hair short
        // of it, and the loop would read again forever on a clock that only
        // moves when it pauses.
        let deadline = start + options.timeout
        var readings = 0
        var woken = 0
        var early = false

        func report(_ outcome: WaitOutcome) -> WaitReport {
            WaitReport(
                outcome: outcome,
                entries: zip(conditions, trackers).map { condition, tracker in
                    WaitReport.Entry(condition: condition, met: tracker.isMet, streak: tracker.streak,
                                     readings: tracker.readings, metAfter: tracker.metAfter, last: tracker.last)
                },
                elapsed: clock.now() - start,
                readings: readings,
                woken: woken,
                listened: listening()
            )
        }

        while true {
            let readAt = clock.now()
            let observations: [WaitObservation]
            do {
                observations = try read(subjects)
            } catch let error as AutomationError {
                return report(.stopped(error))
            } catch {
                return report(.stopped(.failed("\(error)", code: -1)))
            }
            readings += 1
            if early { woken += 1 }

            for (index, condition) in conditions.enumerated() {
                let observation = observations[lookups[index]]
                if WaitRules.readsValue(condition.requirement), case .present(let element) = observation,
                   element.isSecure {
                    return report(.stopped(.secureField(element.described)))
                }
                let reading = WaitRules.reading(observation)
                trackers[index].record(reading, satisfied: WaitRules.satisfies(condition.requirement, reading),
                                       at: readAt - start)
            }

            if trackers.allSatisfy(\.isMet) { return report(.satisfied) }
            if readAt >= deadline { return report(.timedOut) }

            // The next poll, or the deadline — a reading is always taken at
            // the deadline, so something arriving just in time is seen.
            let next = min(readAt + options.interval, deadline)
            early = false
            while clock.now() < next {
                guard clock.pause(next - clock.now()) else { continue }
                // The app said something changed. Read soon — once the burst
                // has landed, and never closer than the minimum gap.
                let soon = min(max(clock.now() + coalesce, readAt + minimumGap), next)
                while clock.now() < soon { _ = clock.pause(soon - clock.now()) }
                early = soon < next
                break
            }
        }
    }
}
