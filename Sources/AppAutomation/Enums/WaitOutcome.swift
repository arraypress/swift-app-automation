//
//  WaitOutcome.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How a wait ended.
public enum WaitOutcome: Sendable, Equatable {

    /// Every condition held, steadily, at the same reading.
    case satisfied

    /// The timeout passed first. The report says what was last seen.
    case timedOut

    /// Something made waiting pointless: the grant went, the screen locked,
    /// the app quit, a password field was asked for its value.
    case stopped(AutomationError)
}
