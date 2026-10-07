//
//  ElementRef.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A way back to one element, that knows when it has gone stale.
///
/// Written `1.3.1#9f2c`: the position and a fingerprint of what was there
/// when it was read. The position's first number picks a top-level element —
/// `0` is the menu bar, `1` and up the windows — and the rest are child
/// indices from there down. Accessibility elements
/// cannot outlive the process that fetched them, so a tool run twice needs
/// something it can print and be handed back. A position alone is not enough:
/// a list re-sorts, a row is inserted, and `0.3.1` is now a different button.
/// The fingerprint is checked before anything is done, and a mismatch is
/// ``AutomationError/stale(_:)`` rather than a press on the wrong thing.
public struct ElementRef: Sendable, Hashable {

    /// The top-level index — 0 the menu bar, 1 and up the windows — then
    /// child indices down.
    public let path: [Int]

    /// Four hex digits identifying the role and label that were read here.
    public let fingerprint: String

    /// A ref from its parts. ``RefCodec/parse(_:)`` reads the written form.
    public init(path: [Int], fingerprint: String) {
        self.path = path
        self.fingerprint = fingerprint
    }
}
