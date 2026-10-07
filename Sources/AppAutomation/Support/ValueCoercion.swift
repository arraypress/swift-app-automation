//
//  ValueCoercion.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Turning what a caller typed into the value an element holds.
//

import Foundation

/// Values as text, and text as values.
///
/// An element's value has a type — a field holds a string, a checkbox a
/// number — and Accessibility will not convert: setting the string `"1"` on a
/// checkbox fails. So the value a caller writes is coerced to the type the
/// element ALREADY holds, which is the only reliable statement of what it
/// expects.
public enum ValueCoercion {

    /// Words accepted as on, for a checkbox or switch.
    static let truthy: Set<String> = ["1", "true", "yes", "on", "checked"]

    /// Words accepted as off.
    static let falsy: Set<String> = ["0", "false", "no", "off", "unchecked"]

    /// A number as text, without a trailing `.0` on a whole number.
    ///
    /// A checkbox reads `1`, not `1.0`; a slider reads `0.25`.
    public static func format(_ number: Double) -> String {
        if number.rounded() == number, abs(number) < 1e15 { return String(Int64(number)) }
        return String(number)
    }

    /// A boolean from a word, or `nil` when the word is neither.
    public static func flag(_ text: String) -> Bool? {
        let word = text.trimmingCharacters(in: .whitespaces).lowercased()
        if truthy.contains(word) { return true }
        if falsy.contains(word) { return false }
        return nil
    }

    /// The value to set, shaped like the one the element holds now.
    ///
    /// - Parameters:
    ///   - text: What the caller wrote.
    ///   - current: The element's present value, which decides the type.
    ///   - isToggle: Whether the element is a checkbox or switch, whose
    ///     number is really a flag.
    /// - Returns: A string or a number, or `nil` when the text cannot be the
    ///   type the element needs — "maybe" for a checkbox, "loud" for a slider.
    public static func value(from text: String, current: AnyObject?, isToggle: Bool) -> AnyObject? {
        if isToggle {
            return flag(text).map { NSNumber(value: $0 ? 1 : 0) }
        }
        if current is NSNumber {
            return Double(text.trimmingCharacters(in: .whitespaces)).map { NSNumber(value: $0) }
        }
        return text as NSString
    }

    /// Whether a value read back is the value that was asked for.
    ///
    /// Numbers compare as numbers, so a slider asked for `0.5` that reads
    /// `0.5000001` has taken it; flags compare as flags; text compares
    /// exactly.
    public static func same(_ wanted: String, _ actual: String?, isToggle: Bool) -> Bool {
        guard let actual else { return false }
        if isToggle, let a = flag(wanted), let b = flag(actual) { return a == b }
        if let a = Double(wanted), let b = Double(actual) {
            return abs(a - b) <= max(1e-6, abs(a) * 1e-6)
        }
        return wanted == actual
    }
}
