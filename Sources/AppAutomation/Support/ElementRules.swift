//
//  ElementRules.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  What can be done to an element, decided from what was read.
//

import Foundation

/// Rules about elements that need no live interface to decide.
public enum ElementRules {

    /// Roles a person can press, set or type into.
    public static let actionableRoles: Set<String> = [
        "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton",
        "AXTextField", "AXTextArea", "AXComboBox", "AXSlider", "AXLink", "AXMenuItem",
        "AXMenuBarItem", "AXDisclosureTriangle", "AXIncrementor", "AXStepper",
        "AXColorWell", "AXCell", "AXRow",
    ]

    /// Roles that are structure and never worth a row on their own unless
    /// they carry a name.
    static let structuralRoles: Set<String> = [
        "AXGroup", "AXScrollArea", "AXSplitGroup", "AXLayoutArea", "AXLayoutItem",
        "AXUnknown", "AXSplitter", "AXScrollBar", "AXValueIndicator", "AXMatte",
        "AXRuler", "AXGrowArea",
    ]

    /// Roles whose value is text somebody can type into.
    static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox"]

    /// Whether the element can be pressed, set or typed into.
    public static func isActionable(_ element: Element) -> Bool {
        actionableRoles.contains(element.role)
            || element.actions.contains("AXPress")
    }

    /// Whether the element is a password field.
    ///
    /// By subrole, which is how both AppKit and Chrome mark one. Checked
    /// before any value is read or written, rather than relying on the value
    /// coming back blank — which it did, measured, but a guard that depends on
    /// another app's good behaviour is not a guard.
    public static func isSecure(role: String, subrole: String?) -> Bool {
        subrole == "AXSecureTextField"
    }

    /// Whether a value can be typed into this kind of element.
    public static func acceptsText(_ element: Element) -> Bool {
        textRoles.contains(element.role)
    }

    /// How to press this element, or `nil` when it cannot be pressed.
    ///
    /// **The action list decides, not the return code.** In Chrome's web
    /// content `AXPress` is absent from the list, and calling it anyway
    /// returns `kAXErrorSuccess` and does nothing — measured on a button whose
    /// click handler changed the page title, which never changed. The header
    /// promises `kAXErrorActionUnsupported` for exactly this case. So an
    /// element without `AXPress` is pressed the way a keyboard user presses
    /// it: focus, then Space — or Return for a link, because Space on a
    /// focused link scrolls the page.
    public static func pressMethod(role: String, actions: [String]) -> PressMethod? {
        if actions.contains("AXPress") { return .press }
        switch role {
        case "AXLink":
            return .focusReturn
        case "AXButton", "AXCheckBox", "AXRadioButton", "AXMenuButton", "AXPopUpButton":
            return .focusSpace
        default:
            return nil
        }
    }

    /// Whether an element is worth showing in a summary of the interface.
    ///
    /// Everything actionable, anything with a name, and the containers that
    /// orient a reader — windows, sheets, dialogs. What is left out is the
    /// unnamed scaffolding: Contacts read whole is 760 elements, most of them
    /// groups inside groups, none of which anybody would ask for by name.
    public static func isWorthShowing(_ element: Element) -> Bool {
        if isActionable(element) { return true }
        if ["AXWindow", "AXSheet", "AXDrawer", "AXApplication"].contains(element.role) { return true }
        if structuralRoles.contains(element.role) { return element.label != nil && element.labelSource != .identifier }
        return element.label != nil
    }
}
