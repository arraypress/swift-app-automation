//
//  Element+Actionable.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension Element {

    /// Whether this can be pressed, set or typed into.
    var isActionable: Bool { ElementRules.isActionable(self) }

    /// How a press would reach it, or `nil` when it cannot be pressed.
    var pressMethod: PressMethod? { ElementRules.pressMethod(role: role, actions: actions) }
}
