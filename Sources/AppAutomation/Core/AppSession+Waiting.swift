//
//  AppSession+Waiting.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Waiting for an interface to reach a state, without touching it.
//

import ApplicationServices
import Darwin
import Foundation

extension AppSession {

    /// Reads the interface until every condition holds, or `options.timeout`
    /// passes. Reads only: nothing is pressed, focused or brought forward.
    ///
    /// ```swift
    /// let save = ElementQuery("Save", role: "button")
    /// let report = try session.wait(until: [WaitCondition(.element(save, in: .focusedWindow), .enabled)])
    /// if report.outcome == .satisfied { try session.press(…) }
    /// ```
    ///
    /// A condition counts only after ``WaitOptions/stable`` identical readings
    /// in a row, so a flicker is not mistaken for the answer. Readings are
    /// taken every ``WaitOptions/interval``, and sooner when the app sends an
    /// Accessibility notification — see ``ChangeObserver``.
    ///
    /// - Returns: A report whatever the outcome. A timeout is not thrown: the
    ///   last state of each condition is the useful part of it.
    /// - Throws: ``AutomationError/notTrusted`` or
    ///   ``AutomationError/screenLocked`` before the first reading, and
    ///   ``AutomationError/noSuchApp(_:)`` when the app has already quit.
    ///   Any of them happening later ends the wait as
    ///   ``WaitOutcome/stopped(_:)``.
    public func wait(until conditions: [WaitCondition], options: WaitOptions = .standard) throws -> WaitReport {
        try ensureReadable()
        guard isRunning else { throw AutomationError.noSuchApp(app.name) }

        // Asked for again, every 50 ms, until the app accepts. Measured on the
        // fixture: an app is a running application ~25 ms after launch but
        // refuses every registration (kAXErrorCannotComplete) until ~150 ms,
        // so a wait started straight after `open` would otherwise poll, deaf,
        // for its whole timeout. Only for the first two seconds: an app that
        // still refuses then is not launching, and asking a hung one again
        // costs a messaging timeout each time.
        let began = ProcessInfo.processInfo.systemUptime
        var observer: ChangeObserver?
        func listen() {
            guard options.listens, observer == nil,
                  ProcessInfo.processInfo.systemUptime - began < Self.listenRetryWindow else { return }
            observer = ChangeObserver(pid: app.pid, element: root)
        }
        listen()
        let clock = WaitClock(
            now: { ProcessInfo.processInfo.systemUptime },
            pause: { seconds in
                let end = ProcessInfo.processInfo.systemUptime + seconds
                while true {
                    let left = end - ProcessInfo.processInfo.systemUptime
                    guard left > 0 else { return false }
                    if let observer { return observer.pause(left) }
                    Thread.sleep(forTimeInterval: min(left, Self.listenRetrySlice))
                    listen()
                }
            }
        )
        let report = WaitLoop.run(conditions, options: options, listening: { observer != nil }, clock: clock) {
            try $0.map(observe)
        }
        observer = nil
        return report
    }

    /// How long a wait keeps asking an app that refused its notifications.
    static let listenRetryWindow: TimeInterval = 2

    /// How often it asks.
    static let listenRetrySlice: TimeInterval = 0.05

    /// What one subject looks like now.
    ///
    /// The library's errors sort into the four answers: the things that mean
    /// "not there" are absent; the things that mean "could not look" are
    /// unreadable; and the things no amount of waiting fixes — no grant, a
    /// locked screen, an app that quit — are thrown, and end the wait.
    func observe(_ subject: WaitSubject) throws -> WaitObservation {
        guard isRunning else { throw AutomationError.noSuchApp(app.name) }
        do {
            switch subject {
            case .element(let query, let scope):
                let read = try snapshot(scope)
                return WaitRules.observe(query, in: read.elements, truncated: read.isTruncated)

            case .ref(let ref):
                return .present(try element(ref))

            case .window(let title):
                // The windows only, not what is in them.
                let read = try snapshot(.window(title), limits: ReadLimits(maxDepth: 0))
                guard let window = read.elements.first else { return .absent("no window titled \(title)") }
                return .present(window)
            }
        } catch let error as AutomationError {
            let reason = error.errorDescription ?? "\(error)"
            switch error {
            case .notTrusted, .screenLocked, .noSuchApp:
                throw error
            case .noWindows, .noSuchWindow, .noSuchElement, .stale:
                return .absent(reason)
            default:
                return .unreadable(reason)
            }
        }
    }

    /// Whether the app's process still exists.
    ///
    /// Asked of the kernel, not of `NSRunningApplication`: the live wait
    /// tests saw a just-launched app reported as not running for a moment,
    /// which ended a wait as "the app quit" a few milliseconds after it began.
    /// EPERM means the process exists and belongs to someone else.
    var isRunning: Bool {
        kill(app.pid, 0) == 0 || errno == EPERM
    }
}
