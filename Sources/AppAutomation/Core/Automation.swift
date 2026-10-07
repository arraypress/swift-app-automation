//
//  Automation.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  The permission, and the apps there are to automate.
//

import AppKit
import ApplicationServices
import Foundation

/// Whether this process may automate other apps, and which apps there are.
public enum Automation {

    /// Whether this process is a trusted Accessibility client.
    ///
    /// **The grant belongs to whatever launched the process**, not to the
    /// binary: run from Terminal, this is true exactly when Terminal is in
    /// System Settings ▸ Privacy & Security ▸ Accessibility. Measured — the
    /// scratch build this library was probed with had never been granted
    /// anything, and was trusted from its first run.
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Whether the screen is locked — in which case nothing can be read or
    /// driven, whatever the permission says. See ``AutomationError/screenLocked``.
    public static var isScreenLocked: Bool {
        SessionState.isScreenLocked
    }

    /// Asks macOS to show its Accessibility prompt, and says whether this
    /// process is trusted already.
    ///
    /// The prompt is asynchronous and the answer is not: this returns the
    /// state before anybody has clicked anything, and a grant usually needs
    /// the granting app restarted before it takes.
    @discardableResult
    public static func requestTrust() -> Bool {
        // The constant's value, spelled out: Swift 6 refuses to read the
        // global `kAXTrustedCheckOptionPrompt` as shared mutable state.
        // Printed from the SDK's own constant rather than assumed.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Running apps, by name.
    ///
    /// - Parameter includeAccessories: Include menu-bar apps and agents
    ///   that have no Dock icon. They often have windows and menus worth
    ///   driving, but listing them by default buries the dozen apps somebody
    ///   is actually using under fifty helpers.
    public static func apps(includeAccessories: Bool = false) -> [RunningApp] {
        NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular
                    || (includeAccessories && $0.activationPolicy == .accessory)
            }
            .map(RunningApp.init)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The one running app a name, bundle identifier or pid names.
    ///
    /// Dock apps are tried first, then menu-bar apps — so `Finder` is never
    /// shadowed by a helper with Finder in its name.
    ///
    /// - Throws: ``AutomationError/noSuchApp(_:)`` or
    ///   ``AutomationError/ambiguousApp(_:_:)``. Needs no permission: an
    ///   unknown app name is answered before trust is ever checked.
    public static func app(matching query: String) throws -> RunningApp {
        for pool in [apps(), apps(includeAccessories: true)] {
            let found = AppMatching.select(query, from: pool)
            if found.count == 1 { return found[0] }
            if found.count > 1 { throw AutomationError.ambiguousApp(query, found.map(\.name)) }
        }
        throw AutomationError.noSuchApp(query)
    }

    /// The frontmost app.
    ///
    /// Run from a terminal, that is usually the terminal.
    public static func frontmost() -> RunningApp? {
        NSWorkspace.shared.frontmostApplication.map(RunningApp.init)
    }
}
