//
//  Keystrokes+Stroke.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension Keystrokes {

    /// One thing to send.
    public enum Stroke: Equatable, Sendable {

        /// Characters, as UTF-16 code units.
        case text([UInt16])

        /// A key with no character: Return, Tab.
        case key(UInt16)
    }
}
