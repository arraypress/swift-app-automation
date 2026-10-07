//
//  RoleNames.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Accessibility's role names, in words a caller would type.
//

import Foundation

/// Short names for roles: `button` for `AXButton`, `secure-field` for a text
/// field whose subrole is `AXSecureTextField`.
///
/// Not localised, unlike `AXRoleDescription`: these are matched against what
/// a script or a language model wrote, and "Taste" is what a German Mac calls
/// a button.
public enum RoleNames {

    /// Subroles that are a different thing to a caller, not a variant.
    ///
    /// A secure field is a text field to AppKit and a password to everybody
    /// else; a tab is a radio button to Accessibility and a tab on screen.
    static let bySubrole: [String: String] = [
        "AXSecureTextField": "secure-field",
        "AXSearchField": "search-field",
        "AXTabButton": "tab",
        "AXCloseButton": "close-button",
        "AXMinimizeButton": "minimize-button",
        "AXZoomButton": "zoom-button",
        "AXFullScreenButton": "full-screen-button",
        "AXDialog": "dialog",
        "AXSystemDialog": "dialog",
        "AXSwitch": "switch",
        "AXToggle": "toggle",
    ]

    /// Roles whose generated name would be awkward.
    static let byRole: [String: String] = [
        "AXCheckBox": "checkbox",
        "AXRadioButton": "radio",
        "AXPopUpButton": "popup",
        "AXComboBox": "combo-box",
        "AXStaticText": "text",
        "AXMenuBarItem": "menu",
        "AXTabGroup": "tabs",
        "AXIncrementor": "stepper",
        "AXProgressIndicator": "progress",
        "AXValueIndicator": "indicator",
        "AXApplication": "app",
        "AXWebArea": "web-area",
    ]

    /// The short name for a role and subrole.
    public static func kind(role: String, subrole: String? = nil) -> String {
        if let subrole, let name = bySubrole[subrole] { return name }
        if let name = byRole[role] { return name }
        return hyphenated(role)
    }

    /// `AXDisclosureTriangle` → `disclosure-triangle`.
    static func hyphenated(_ role: String) -> String {
        let bare = role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
        var out = ""
        for character in bare {
            if character.isUppercase, !out.isEmpty { out.append("-") }
            out.append(contentsOf: character.lowercased())
        }
        return out.isEmpty ? role.lowercased() : out
    }

    /// Whether a role a caller wrote names this element.
    ///
    /// Takes either form: `button` and `AXButton` both match a button, and
    /// `text-field` matches a search field too, because a search field is a
    /// text field to anybody asking for one.
    public static func matches(_ wanted: String, role: String, subrole: String?) -> Bool {
        let wanted = wanted.lowercased()
        if wanted == role.lowercased() { return true }
        if let subrole, wanted == subrole.lowercased() { return true }
        let kind = kind(role: role, subrole: subrole)
        if wanted == kind { return true }
        // The generic name for the role still matches its specialised form.
        return wanted == hyphenated(role) && kind != "secure-field"
    }
}
