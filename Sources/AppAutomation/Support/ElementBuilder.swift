//
//  ElementBuilder.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Turning one element's attribute values into an ``Element``.
//

import ApplicationServices
import Foundation

/// Assembling an ``Element`` from what was read.
///
/// Separate from the reader so the rules — what counts as a label, what is
/// never read from a password field — are applied in one place, to values
/// rather than to a live element.
enum ElementBuilder {

    /// The element described by a batched read.
    ///
    /// - Parameters:
    ///   - values: What ``AXRead/values(of:names:)`` returned.
    ///   - path: Its path from the top level down — see ``ElementRef``.
    ///   - actions: What the element says can be done to it.
    ///   - titledBy: The text of the element named by `AXTitleUIElement`.
    ///   - text: Text found inside the element, for one with no name.
    static func element(
        from values: [String: AnyObject],
        path: [Int],
        actions: [String],
        titledBy: String?,
        text: String?
    ) -> Element {
        let role = AXRead.text(values[kAXRoleAttribute]) ?? "AXUnknown"
        let subrole = AXRead.text(values[kAXSubroleAttribute])
        let isSecure = ElementRules.isSecure(role: role, subrole: subrole)

        // Never read, never stored. The OS returned a blank for the fixture's
        // password field anyway; this does not depend on it doing so.
        let value = isSecure ? nil : AXRead.text(values[kAXValueAttribute])

        let (label, source) = Labeling.label(from: Labeling.Candidates(
            role: role,
            subrole: subrole,
            title: AXRead.text(values[kAXTitleAttribute]),
            description: AXRead.text(values[kAXDescriptionAttribute]),
            titledBy: titledBy,
            placeholder: AXRead.text(values[kAXPlaceholderValueAttribute]),
            text: text,
            help: AXRead.text(values[kAXHelpAttribute]),
            value: value,
            identifier: AXRead.text(values[kAXIdentifierAttribute])
        ))

        var frame: Frame?
        if let origin = AXRead.point(values[kAXPositionAttribute]),
           let size = AXRead.size(values[kAXSizeAttribute]) {
            frame = Frame(x: origin.x, y: origin.y, width: size.width, height: size.height)
        }

        return Element(
            ref: ElementRef(path: path, fingerprint: RefCodec.fingerprint(role: role, label: label)),
            depth: path.count,
            role: role,
            subrole: subrole,
            roleDescription: AXRead.text(values[kAXRoleDescriptionAttribute]),
            label: label,
            labelSource: source,
            value: value,
            identifier: Labeling.meaningfulIdentifier(AXRead.text(values[kAXIdentifierAttribute])),
            help: AXRead.text(values[kAXHelpAttribute]),
            frame: frame,
            isEnabled: AXRead.bool(values[kAXEnabledAttribute]) ?? true,
            isFocused: AXRead.bool(values[kAXFocusedAttribute]) ?? false,
            isSecure: isSecure,
            isSelected: AXRead.bool(values[kAXSelectedAttribute]) ?? false,
            actions: actions
        )
    }

    /// The same element with a label found inside it.
    ///
    /// A table row has no name of its own; its name is the text in its first
    /// cell. That text is only known once the children have been read, so the
    /// row is read first and named afterwards — and its fingerprint follows
    /// its new label, so a ref to it means the row, not the position.
    static func named(_ element: Element, text: String) -> Element {
        let (label, source) = Labeling.label(from: Labeling.Candidates(role: element.role, text: text))
        return Element(
            ref: ElementRef(
                path: element.ref.path,
                fingerprint: RefCodec.fingerprint(role: element.role, label: label)
            ),
            depth: element.depth,
            role: element.role,
            subrole: element.subrole,
            roleDescription: element.roleDescription,
            label: label,
            labelSource: source,
            value: element.value,
            identifier: element.identifier,
            help: element.help,
            frame: element.frame,
            isEnabled: element.isEnabled,
            isFocused: element.isFocused,
            isSecure: element.isSecure,
            isSelected: element.isSelected,
            actions: element.actions
        )
    }
}
