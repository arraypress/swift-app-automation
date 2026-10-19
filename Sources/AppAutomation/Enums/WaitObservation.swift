//
//  WaitObservation.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What one reading found for a ``WaitSubject``.
///
/// Four answers, not two, because "not there" and "could not look" are
/// different results to a caller: a window on another Space is not a window
/// that closed, and an app that did not answer has not had its button
/// disappear.
public enum WaitObservation: Sendable, Equatable {

    /// Exactly one match, as read.
    case present(Element)

    /// No match, and the reading was complete enough to say so. Carries why.
    case absent(String)

    /// Several matches. A wait never picks one: which of two "Save" buttons
    /// became enabled is the question a caller needs answered.
    case ambiguous([Element])

    /// The app could not be read well enough to say: hidden, on another
    /// Space, not answering, or a tree cut off before the end. Carries why.
    case unreadable(String)
}
