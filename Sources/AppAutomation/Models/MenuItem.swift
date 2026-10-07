//
//  MenuItem.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One item in an app's menu bar.
public struct MenuItem: Sendable, Equatable, Codable {

    /// Titles from the menu bar down: `["File", "New Folder"]`.
    public let path: [String]

    /// Whether it can be chosen right now.
    public let isEnabled: Bool

    /// Whether it carries a check mark.
    public let isChecked: Bool

    /// The keyboard shortcut as the menu shows it: `⌘⇧N`.
    public let shortcut: String?

    /// Whether it opens a submenu rather than doing something.
    public let hasSubmenu: Bool

    /// A menu item from its parts. Built by ``AppSession/menuItems(depth:)``.
    public init(
        path: [String],
        isEnabled: Bool = true,
        isChecked: Bool = false,
        shortcut: String? = nil,
        hasSubmenu: Bool = false
    ) {
        self.path = path
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.shortcut = shortcut
        self.hasSubmenu = hasSubmenu
    }
}
