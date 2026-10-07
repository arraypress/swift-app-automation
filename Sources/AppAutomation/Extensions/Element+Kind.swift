//
//  Element+Kind.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension Element {

    /// The short name for what this is: `button`, `text-field`, `secure-field`.
    var kind: String { RoleNames.kind(role: role, subrole: subrole) }

    /// `button “Save”`, for messages.
    var described: String {
        guard let label else { return kind }
        return "\(kind) “\(label)”"
    }
}
