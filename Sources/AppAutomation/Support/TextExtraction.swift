//
//  TextExtraction.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  An interface as the words on it.
//

import Foundation

/// The readable text in a snapshot, in reading order.
///
/// What an agent wants more often than a tree: "what does this window say?"
/// Read from the interface rather than a screenshot, so it is exact, it costs
/// no OCR, and it includes text scrolled out of view.
public enum TextExtraction {

    /// Roles whose words are content.
    static let contentRoles: Set<String> = [
        "AXStaticText", "AXHeading", "AXTextArea", "AXTextField", "AXLink", "AXCell",
    ]

    /// One line per piece of text, consecutive duplicates collapsed.
    ///
    /// Collapsed because Chrome reports a heading AND the static text inside
    /// it, both carrying the same words; printed twice, every heading reads
    /// as a stutter. Password fields contribute nothing.
    public static func lines(from elements: [Element]) -> [String] {
        var out: [String] = []
        for element in elements where contentRoles.contains(element.role) && !element.isSecure {
            let words = element.role == "AXTextArea" || element.role == "AXTextField"
                ? element.value
                : (element.label ?? element.value)
            guard let words = Labeling.clean(words) else { continue }
            if out.last != words { out.append(words) }
        }
        return out
    }
}
