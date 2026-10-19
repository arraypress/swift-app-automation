//
//  WaitSubject.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a wait looks at: one element, or a window.
public enum WaitSubject: Sendable, Equatable {

    /// The element a query means, in a part of the app — the same targeting
    /// as ``AppSession/find(_:in:)``. More than one match is
    /// ``WaitObservation/ambiguous(_:)``, never the first of them.
    case element(ElementQuery, in: TreeScope)

    /// The element at a ref, fingerprint checked: something else at that
    /// position is the element gone, not the element changed.
    case ref(ElementRef)

    /// Any window whose title contains this, ignoring case — what
    /// ``TreeScope/window(_:)`` reads.
    case window(String)
}
