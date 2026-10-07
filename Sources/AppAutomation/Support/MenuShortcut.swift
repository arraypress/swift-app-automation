//
//  MenuShortcut.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  A menu item's keyboard shortcut, written the way the menu shows it.
//

import Foundation

/// `⌘⇧N` from Accessibility's character and modifier mask.
public enum MenuShortcut {

    /// The written shortcut, or `nil` for an item with none.
    ///
    /// The mask is the header's, verified in `AXAttributeConstants.h`: Shift
    /// is bit 0, Option bit 1, Control bit 2, and bit 3 means **no Command**.
    /// Command is the default — an item with a mask of 0 is `⌘<key>` — which
    /// is the opposite of how every other modifier works and the reason this
    /// is a function with a test rather than a one-liner.
    ///
    /// Symbols in the order macOS menus draw them: ⌃⌥⇧⌘.
    public static func format(character: String?, modifiers: Int) -> String? {
        guard let character, !character.isEmpty else { return nil }
        var out = ""
        if modifiers & 4 != 0 { out += "⌃" }
        if modifiers & 2 != 0 { out += "⌥" }
        if modifiers & 1 != 0 { out += "⇧" }
        if modifiers & 8 == 0 { out += "⌘" }
        return out + character
    }
}
