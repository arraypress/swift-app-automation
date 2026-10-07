//
//  ActionResult.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What happened when an element was acted on.
public struct ActionResult: Sendable, Equatable, Codable {

    /// The element, as it was read just before acting.
    public let element: Element

    /// What was done: `press`, `set`, `type`, `focus`, `pick`, `menu`.
    public let action: String

    /// How a press was delivered, when it was a press.
    public let method: PressMethod?

    /// Whether the result was read back and found right.
    ///
    /// `true` means checked and confirmed. `nil` means **not checkable** — a
    /// button press has no value to read back, and a web checkbox reports
    /// nothing whatever its state. It is never `false`: a check that fails is
    /// ``AutomationError/notApplied(expected:actual:)`` instead.
    public let verified: Bool?

    /// The element's value after acting, where it has one.
    public let valueAfter: String?

    /// Anything a caller should know that is not a failure.
    ///
    /// The commonest: the app did not answer within the timeout after a
    /// press, which measured against a real modal alert means a dialog opened
    /// — the press worked, and the app is now waiting on somebody.
    public let note: String?

    /// Records an outcome. Built by ``AppSession``; public for tests and fakes.
    public init(
        element: Element,
        action: String,
        method: PressMethod? = nil,
        verified: Bool? = nil,
        valueAfter: String? = nil,
        note: String? = nil
    ) {
        self.element = element
        self.action = action
        self.method = method
        self.verified = verified
        self.valueAfter = valueAfter
        self.note = note
    }
}
