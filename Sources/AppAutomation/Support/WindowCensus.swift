//
//  WindowCensus.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Counting an app's windows without Accessibility.
//

import CoreGraphics
import Foundation

/// The window server's count of an app's windows.
///
/// Exists to tell two answers apart that Accessibility gives identically.
/// An app with no windows and an app whose windows are on another Space both
/// report an empty `AXWindows` — measured: Notes, with **six** real windows
/// on another desktop, reported **zero**. The window server still lists them,
/// marked off-screen, so asking it is how "nothing open" becomes "open, but
/// somewhere you are not looking".
///
/// Reads window metadata only — never contents — so it needs no Screen
/// Recording permission.
enum WindowCensus {

    /// Ordinary windows the app owns that are not on screen.
    ///
    /// Layer 0 only: menus, the menu bar's extras and tooltips live on other
    /// layers, and every app has some of those whether or not it has a
    /// window open.
    static func offscreenWindows(of pid: pid_t) -> Int {
        guard let info = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        return info.filter {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == pid
                && ($0[kCGWindowLayer as String] as? Int) == 0
                && ($0[kCGWindowIsOnscreen as String] as? Bool) != true
        }.count
    }
}
