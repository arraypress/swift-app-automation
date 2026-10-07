//
//  LabelSource.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where an element's label was found.
///
/// Worth recording because the sources are not equally trustworthy. A title
/// is what the app shows; a description is what it tells VoiceOver; an
/// identifier is a developer's name for a view and may mean nothing to a
/// person. The order they are tried in is ``Labeling/label(from:)``'s.
public enum LabelSource: String, Sendable, Equatable, Codable, CaseIterable {

    /// The element's own title: a button's text, a window's name.
    case title

    /// What the app tells VoiceOver. Icon buttons usually only have this.
    case description

    /// A separate label element the app linked to this one — the "Name:"
    /// beside a field.
    case titledBy

    /// A text field's placeholder.
    case placeholder

    /// Text inside the element: a table cell's contents.
    case text

    /// The tooltip.
    case help

    /// The element's own value, for things whose value IS their text — a
    /// piece of static text, a heading.
    case value

    /// A developer-assigned identifier.
    case identifier

    /// The role refinement, for the window buttons, which carry nothing else:
    /// `AXCloseButton` is the only name a window's close button has.
    case subrole

    /// Nothing at all.
    case none
}
