//
//  SessionState.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Whether the login session can be automated at all right now.
//

import CoreGraphics
import Foundation

/// The state of the login session, from the window server.
///
/// **A locked screen hides every window from Accessibility.** Measured with
/// the screen locked: Mail, Contacts, Music, System Settings and Sidewatch
/// each reported 163 elements and not one control — the menu bar and nothing
/// else — and Finder listed itself as its own child until a walk stopped at
/// 30,000 copies of it. Apps cannot be brought forward either. Every one of
/// those reads would otherwise come back as "nothing matches", which is the
/// wrong answer to give an agent running unattended on a Mac that locked
/// itself at night.
enum SessionState {

    /// The session dictionary key the window server sets while locked.
    static let lockedKey = "CGSSessionScreenIsLocked"

    /// Whether the screen is locked.
    static var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return isLocked(session)
    }

    /// Reads the lock flag out of a session dictionary.
    ///
    /// Separate so the rule can be tested without locking anything. Measured
    /// locked, the key was present as `1`; anything else — absent, `0` — is
    /// read as unlocked, so a session dictionary that changes shape fails
    /// open into the reads' own errors rather than refusing every call.
    static func isLocked(_ session: [String: Any]) -> Bool {
        (session[lockedKey] as? NSNumber)?.boolValue ?? false
    }
}
