//
//  RunningApp+Workspace.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import AppKit

extension RunningApp {

    /// A value from AppKit's live reference.
    init(_ application: NSRunningApplication) {
        self.init(
            pid: application.processIdentifier,
            name: application.localizedName ?? application.bundleIdentifier ?? "pid \(application.processIdentifier)",
            bundleID: application.bundleIdentifier,
            isActive: application.isActive,
            isHidden: application.isHidden
        )
    }
}
