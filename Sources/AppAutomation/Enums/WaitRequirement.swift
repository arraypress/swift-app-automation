//
//  WaitRequirement.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What must be true of a ``WaitSubject``.
///
/// Everything but ``gone`` needs the subject there — exactly one of it — so
/// "is enabled" also means "exists".
public enum WaitRequirement: Sendable, Equatable {

    /// It is there.
    case exists

    /// It is not: nothing matches, or a ref's position now holds something
    /// else.
    case gone

    /// Its value is exactly this, case and all — a value is data, not a name.
    case valueEquals(String)

    /// Its value contains this, case and all.
    case valueContains(String)

    /// It accepts input.
    case enabled

    /// It does not.
    case disabled

    /// It is selected — a row, a tab, a cell — or, for a checkbox or radio
    /// button, on.
    case selected
}
