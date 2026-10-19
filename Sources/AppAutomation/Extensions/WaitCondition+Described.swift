//
//  WaitCondition+Described.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension WaitCondition {

    /// `button “Save” is enabled`, for messages.
    var described: String { WaitRules.describe(self) }
}
