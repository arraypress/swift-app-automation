//
//  ElementQuery.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What to look for in an interface.
///
/// ```swift
/// ElementQuery("Save", role: "button")
/// ElementQuery("name", role: "text-field")
/// ElementQuery(identifier: "ConversationList")
/// ```
public struct ElementQuery: Sendable, Equatable {

    /// Text to match against the label, ignoring case. `nil` matches anything.
    public let text: String?

    /// A role to require, either friendly (`button`, `text-field`) or
    /// Accessibility's own (`AXButton`). `nil` matches any.
    public let role: String?

    /// Whether the label must equal ``text`` rather than contain it.
    public let exact: Bool

    /// A developer-assigned `AXIdentifier` to require, compared whole and
    /// case-sensitively — it is a name in somebody's code, not a sentence.
    /// `nil` matches any.
    public let identifier: String?

    /// Whether to consider only things that can be pressed, set or typed into.
    public let actionableOnly: Bool

    /// A query.
    ///
    /// - Parameters:
    ///   - text: Label text; `nil` matches any.
    ///   - role: A role, either form; `nil` matches any.
    ///   - exact: Require the whole label.
    ///   - identifier: An `AXIdentifier`, whole; `nil` matches any.
    ///   - actionableOnly: Skip what cannot be acted on.
    public init(
        _ text: String? = nil,
        role: String? = nil,
        exact: Bool = false,
        identifier: String? = nil,
        actionableOnly: Bool = false
    ) {
        self.text = text
        self.role = role
        self.exact = exact
        self.identifier = identifier
        self.actionableOnly = actionableOnly
    }
}
