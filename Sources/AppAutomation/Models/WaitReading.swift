//
//  WaitReading.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What one reading saw of a condition's subject — the part a condition can
/// look at, and nothing else.
///
/// Two readings are "the same" when these are equal, which is what stability
/// counts. Where the element is on screen is left out on purpose: a window
/// dragged two pixels has not changed its answer.
public struct WaitReading: Sendable, Equatable {

    /// The four kinds of answer a reading can give.
    public enum State: String, Sendable, Equatable {
        case present, absent, ambiguous, unreadable
    }

    /// Which kind of answer.
    public let state: State

    /// The element's ref, when exactly one was there.
    public let ref: ElementRef?

    /// Its short kind: `button`, `window`.
    public let kind: String?

    /// Its label.
    public let label: String?

    /// Its value, whole. Never read for a password field.
    public let value: String?

    /// Whether it accepts input.
    public let isEnabled: Bool?

    /// Whether it is selected, or on.
    public let isSelected: Bool?

    /// The refs of every match, when there were several.
    public let candidates: [ElementRef]

    /// Why it was absent or unreadable.
    public let reason: String?

    /// A reading from its parts. Built by the wait; public for fakes.
    public init(
        state: State,
        ref: ElementRef? = nil,
        kind: String? = nil,
        label: String? = nil,
        value: String? = nil,
        isEnabled: Bool? = nil,
        isSelected: Bool? = nil,
        candidates: [ElementRef] = [],
        reason: String? = nil
    ) {
        self.state = state
        self.ref = ref
        self.kind = kind
        self.label = label
        self.value = value
        self.isEnabled = isEnabled
        self.isSelected = isSelected
        self.candidates = candidates
        self.reason = reason
    }

    /// Equal when a condition could not tell them apart. The reason is
    /// commentary — "no windows" and "nothing matches" are both absent.
    public static func == (lhs: WaitReading, rhs: WaitReading) -> Bool {
        lhs.state == rhs.state && lhs.ref == rhs.ref && lhs.value == rhs.value
            && lhs.isEnabled == rhs.isEnabled && lhs.isSelected == rhs.isSelected
            && lhs.candidates == rhs.candidates
    }
}
