//
//  TreeScope.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Which part of an app to read.
public enum TreeScope: Sendable, Equatable {

    /// The window with keyboard focus, falling back to the main window.
    ///
    /// The default, because it is nearly always what was meant and it is a
    /// fraction of the cost: Contacts read whole is 760 elements.
    case focusedWindow

    /// Every window the app has on this Space.
    case allWindows

    /// The window whose title contains this, ignoring case.
    case window(String)

    /// The menu bar. ``AppSession/menuItems()`` reads it as paths, which is
    /// usually the better shape.
    case menuBar
}
