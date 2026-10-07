//
//  AXRead.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Reading attributes out of a live element, and turning Core Foundation
//  values into Swift ones.
//

import ApplicationServices
import Foundation

/// Reading from a live `AXUIElement`.
///
/// **One round trip per element, not one per attribute.** Every read is an
/// IPC call into the other app, and the other app answers on its main
/// thread. Asking for thirteen attributes one at a time across Contacts took
/// **2.76 s**; asking for all of them in one `AXUIElementCopyMultipleAttributeValues`
/// call took **0.43 s** — 6.4× — for the same 760 elements. System Settings:
/// 1.09 s against 0.39 s.
enum AXRead {

    /// What a snapshot reads from every element, in this order.
    static let attributes: [String] = [
        kAXRoleAttribute,
        kAXSubroleAttribute,
        kAXRoleDescriptionAttribute,
        kAXTitleAttribute,
        kAXDescriptionAttribute,
        kAXValueAttribute,
        kAXIdentifierAttribute,
        kAXHelpAttribute,
        kAXPlaceholderValueAttribute,
        kAXTitleUIElementAttribute,
        kAXPositionAttribute,
        kAXSizeAttribute,
        kAXEnabledAttribute,
        kAXFocusedAttribute,
        kAXChildrenAttribute,
    ]

    /// Every attribute in ``attributes``, by name, with failures dropped.
    ///
    /// A batched read reports a failed attribute in place — as an `AXValue`
    /// of type `.axError`, or `CFNull` — rather than leaving it out, so a
    /// missing title arrives as something that is not a string and has to be
    /// recognised and discarded rather than printed.
    static func values(of element: AXUIElement, names: [String] = attributes) -> [String: AnyObject] {
        var raw: CFArray?
        let status = AXUIElementCopyMultipleAttributeValues(element, names as CFArray, [], &raw)
        guard status == .success, let array = raw as? [AnyObject] else { return [:] }

        var out: [String: AnyObject] = [:]
        for (name, value) in zip(names, array) where !isFailure(value) {
            out[name] = value
        }
        return out
    }

    /// Whether a batched value is an error or a null standing in for one.
    static func isFailure(_ value: AnyObject) -> Bool {
        if value is NSNull { return true }
        let ref = value as CFTypeRef
        guard CFGetTypeID(ref) == AXValueGetTypeID() else { return false }
        return AXValueGetType(ref as! AXValue) == .axError
    }

    /// One attribute, with the error kept.
    static func attribute(_ name: String, of element: AXUIElement) -> (value: CFTypeRef?, status: AXError) {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return (value, status)
    }

    /// An element's children, or none.
    static func children(of element: AXUIElement) -> [AXUIElement] {
        (attribute(kAXChildrenAttribute, of: element).value as? [AXUIElement]) ?? []
    }

    /// What an element says can be done to it.
    static func actions(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    /// Whether an attribute can be written.
    static func isSettable(_ name: String, of element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success else {
            return false
        }
        return settable.boolValue
    }

    // MARK: - Decoding

    /// Text, from a string or a number.
    ///
    /// A checkbox's value is the number `1`, a slider's `0.5`; both are worth
    /// showing. A structure — a range, a point — is not text and comes back
    /// `nil` rather than as `<AXValue 0x…>`.
    static func text(_ value: AnyObject?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "1" : "0" }
            return ValueCoercion.format(number.doubleValue)
        case let url as URL:
            return url.absoluteString
        default:
            return nil
        }
    }

    /// A boolean, from `CFBoolean` or a number.
    static func bool(_ value: AnyObject?) -> Bool? {
        (value as? NSNumber)?.boolValue
    }

    /// A point out of an `AXValue`.
    static func point(_ value: AnyObject?) -> CGPoint? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    /// A size out of an `AXValue`.
    static func size(_ value: AnyObject?) -> CGSize? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }

    /// An element out of an attribute that holds one.
    static func element(_ value: AnyObject?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
}
