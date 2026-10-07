//
//  Labeling.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Deciding what an element is called.
//

import Foundation

/// Finding the name a person would use for an element.
///
/// Accessibility has no single "label" attribute. An app may put the name in
/// any of half a dozen places, and which one varies by app, by framework and
/// by control. Measured across the sixteen apps running on the machine this
/// was built on, the first non-empty source for an actionable control was:
///
/// | source | Finder | Mail | Contacts | Music |
/// |---|---|---|---|---|
/// | separate label element | 78 | 3 | 90 | 11 |
/// | description | 32 | 97 | 16 | 41 |
/// | identifier | 12 | 74 | 1 | 1 |
/// | value | 14 | — | — | — |
/// | title | 1 | 3 | — | 12 |
///
/// So the order below is chosen to prefer what a person SEES over what a
/// developer typed: a title, then what the app tells VoiceOver, then the
/// label beside it, and only then the identifier — which may be
/// `ConversationList`, a name meaning something only to the person who wrote
/// it.
public enum Labeling {

    /// Roles whose value IS their text, and so a fair name for them.
    ///
    /// A text FIELD is not here, deliberately: its value is what somebody
    /// typed into it. Naming a field by its contents means the field called
    /// "Name" is renamed "Ada" the moment anybody fills it in, and every
    /// instruction written against it stops matching.
    public static let rolesNamedByValue: Set<String> = [
        "AXStaticText", "AXHeading", "AXMenuBarItem",
    ]

    /// The label and where it came from.
    public static func label(from candidates: Candidates) -> (label: String?, source: LabelSource) {
        let ordered: [(String?, LabelSource)] = [
            (candidates.title, .title),
            (candidates.description, .description),
            (candidates.titledBy, .titledBy),
            (candidates.placeholder, .placeholder),
            (candidates.text, .text),
            (rolesNamedByValue.contains(candidates.role) ? candidates.value : nil, .value),
            (candidates.help, .help),
            (meaningfulIdentifier(candidates.identifier), .identifier),
        ]
        for (value, source) in ordered {
            if let cleaned = clean(value) { return (cleaned, source) }
        }
        if let subrole = candidates.subrole, windowButtonSubroles.contains(subrole) {
            return (RoleNames.kind(role: candidates.role, subrole: subrole), .subrole)
        }
        return (nil, .none)
    }

    /// The window buttons, which carry no name but their subrole.
    ///
    /// Every window's close, minimise and zoom buttons came back with nothing
    /// but this — in every app measured.
    static let windowButtonSubroles: Set<String> = [
        "AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton",
    ]

    /// An identifier, unless it is one AppKit made up.
    ///
    /// `_NS:<n>` is generated for views loaded from a nib that the developer
    /// never named — **1,195 of about 4,400** identifiers across the running
    /// apps measured. It means nothing to anybody, and as a label it would
    /// make an unnamed button look named.
    static func meaningfulIdentifier(_ identifier: String?) -> String? {
        guard let identifier, !identifier.hasPrefix("_NS:") else { return nil }
        return identifier
    }

    /// Trimmed, single-line, or `nil` when there is nothing left.
    ///
    /// A label with a newline in it breaks every one-row-per-element output,
    /// and leading spaces make an exact match fail for no visible reason.
    static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let flattened = value
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return flattened.isEmpty ? nil : flattened
    }
}
