//
//  Frame.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where an element sits on screen, in points.
///
/// The origin is the **top-left** of the main display, the way Accessibility
/// and Core Graphics events count — not the bottom-left AppKit uses for
/// windows. Mixing the two puts a click a screen's height away from its target.
public struct Frame: Sendable, Equatable, Codable {

    /// Distance from the left edge of the main display.
    public let x: Double

    /// Distance from the TOP edge of the main display.
    public let y: Double

    /// Width, in points.
    public let width: Double

    /// Height, in points.
    public let height: Double

    /// A frame from its parts.
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
