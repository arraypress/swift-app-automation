//
//  WaitCondition.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One thing a wait needs to be true: a subject and a requirement on it.
///
/// ```swift
/// WaitCondition(.element(ElementQuery("Save", role: "button"), in: .focusedWindow), .enabled)
/// WaitCondition(.window("Untitled"), .exists)
/// ```
///
/// Several conditions are ANDed: a wait is satisfied when every one of them
/// holds at the same reading.
public struct WaitCondition: Sendable, Equatable {

    /// What to look at.
    public let subject: WaitSubject

    /// What must be true of it.
    public let requirement: WaitRequirement

    /// A condition.
    public init(_ subject: WaitSubject, _ requirement: WaitRequirement = .exists) {
        self.subject = subject
        self.requirement = requirement
    }
}
