//
//  RunningApp.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An app that is running, as a value.
public struct RunningApp: Sendable, Equatable, Codable, Identifiable {

    /// The process identifier — the one thing that names this app exactly.
    public let pid: Int32

    /// What the Dock calls it: `Finder`, `Google Chrome`.
    public let name: String

    /// `com.apple.finder`. `nil` for a bare executable with no bundle.
    public let bundleID: String?

    /// Whether it is the frontmost app.
    public let isActive: Bool

    /// Whether it is hidden. A hidden app's windows cannot be read.
    public let isHidden: Bool

    /// The pid, which is what tells two copies of one app apart.
    public var id: Int32 { pid }

    /// An app from its parts. ``Automation/apps(includeAccessories:)`` lists real ones.
    public init(pid: Int32, name: String, bundleID: String?, isActive: Bool, isHidden: Bool) {
        self.pid = pid
        self.name = name
        self.bundleID = bundleID
        self.isActive = isActive
        self.isHidden = isHidden
    }
}
