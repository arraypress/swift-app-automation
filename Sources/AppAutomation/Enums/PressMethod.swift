//
//  PressMethod.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How a press reached the element.
///
/// There are three because there has to be. Native controls answer
/// `AXPress`. Web content does not — measured in Chrome, a button, a link and
/// a checkbox all offer only `AXShowMenu` and `AXScrollToVisible` — and the
/// way a person presses those from the keyboard works instead: focus, then
/// Space for a button, Return for a link. Both keyboard routes worked with
/// Chrome in the background.
public enum PressMethod: String, Sendable, Equatable, Codable, CaseIterable {

    /// The element's own `AXPress` action.
    case press

    /// Focus the element, then a Space key event sent to its app.
    ///
    /// Buttons and checkboxes. Not links: Space on a focused link scrolls the
    /// page.
    case focusSpace = "focus+space"

    /// Focus the element, then a Return key event sent to its app. Links.
    case focusReturn = "focus+return"
}
