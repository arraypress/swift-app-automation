//
//  WindowCensus.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Counting an app's windows without Accessibility.
//

import AppKit
import CoreGraphics
import Foundation

/// The window server's count of an app's windows on other Spaces.
///
/// Exists to tell two answers apart that Accessibility gives identically.
/// An app with no windows and an app whose windows are on another Space both
/// report an empty `AXWindows` — measured: Notes, with **six** real windows
/// on another desktop, reported **zero**. The window server still lists them,
/// marked off-screen, so asking it is how "nothing open" becomes "open, but
/// somewhere you are not looking".
///
/// **Off-screen is not enough.** Measured on macOS 27 (one Space, 19 apps):
/// 92 layer-0 windows were off-screen, and 91 of them were on no Space at
/// all — AppKit's scaffolding (a screen-wide strip 39 pt tall per closed
/// document window, an unplaced 500×500, cursor helpers) and windows an app
/// closed but kept alive, ordered out: Notes 1000×660, Mail 420×632, a
/// settings window 740×960. Counted, every app with no window open read as
/// "windows on another Space", and a wait for its last window to close could
/// never succeed. A window that is somewhere is in AppKit's all-Spaces
/// window list; an ordered-out one is not. The one off-screen window that
/// WAS listed belonged to a hidden app, which is reported before this is
/// asked.
///
/// Not measured: a window on a second Space, because this Mac has one and
/// making another means moving somebody's windows. That such windows are in
/// the list is AppKit's documented meaning of `.allSpaces`.
///
/// Reads window metadata only — never contents — so it needs no Screen
/// Recording permission.
enum WindowCensus {

    /// Ordinary windows the app owns that are on a Space but not on screen.
    static func offscreenWindows(of pid: pid_t) -> Int {
        guard let info = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        // Without the list, the old answer: every off-screen window counts.
        // Over-reporting "on another Space" is the safe direction — it makes
        // a wait say it cannot tell, never that something has gone.
        guard let listed = listedWindowNumbers() else {
            return elsewhere(info, pid: pid, listed: nil)
        }
        return elsewhere(info, pid: pid, listed: listed)
    }

    /// AppKit's all-Spaces window list, read on the main thread as AppKit
    /// requires.
    ///
    /// Called off it — `axe` reads from a concurrency thread — this asks the
    /// main thread and waits at most a second, so a caller that blocks the
    /// main thread while it waits for this gets `nil` rather than a deadlock.
    static func listedWindowNumbers() -> Set<Int>? {
        if Thread.isMainThread { return MainActor.assumeIsolated { allSpacesWindowNumbers() } }
        let answer = Answer()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            answer.numbers = MainActor.assumeIsolated { allSpacesWindowNumbers() }
            done.signal()
        }
        return done.wait(timeout: .now() + 1) == .success ? answer.numbers : nil
    }

    @MainActor
    private static func allSpacesWindowNumbers() -> Set<Int> {
        Set((NSWindow.windowNumbers(options: [.allApplications, .allSpaces]) ?? []).map(\.intValue))
    }

    /// Where the main thread leaves its answer; the semaphore orders the write
    /// before the read, and a late answer is never read.
    private final class Answer: @unchecked Sendable {
        var numbers: Set<Int>?
    }

    /// The windows in a window-server listing that belong to `pid` and are
    /// somewhere other than on screen.
    ///
    /// Layer 0 only: menus, the menu bar's extras and tooltips live on other
    /// layers. Off-screen, and in `listed` — AppKit's all-Spaces window list —
    /// so that windows on no Space at all are not mistaken for windows on
    /// another one. `nil` for `listed` counts every off-screen window.
    static func elsewhere(_ info: [[String: Any]], pid: pid_t, listed: Set<Int>?) -> Int {
        info.filter {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == pid
                && ($0[kCGWindowLayer as String] as? Int) == 0
                && ($0[kCGWindowIsOnscreen as String] as? Bool) != true
                && (listed == nil || ($0[kCGWindowNumber as String] as? Int).map { listed!.contains($0) } == true)
        }.count
    }
}
