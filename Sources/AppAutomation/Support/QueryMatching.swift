//
//  QueryMatching.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Which elements a query means.
//

import Foundation

/// Matching a query against read elements.
///
/// Pure: it sees values, never the live interface, so every rule here is
/// tested on hand-built lists.
public enum QueryMatching {

    /// The elements a query means, best first.
    ///
    /// **An exact label beats a partial one.** Asked for `Save` in a window
    /// with `Save` and `Save As…`, the answer is `Save` — not "two matches,
    /// choose". Only when nothing is called exactly that do partial matches
    /// count, and then all of them do.
    public static func select(_ query: ElementQuery, from elements: [Element]) -> [Element] {
        let candidates = elements.filter { qualifies($0, query) }
        guard let text = query.text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else {
            return candidates
        }

        let exact = candidates.filter { $0.label?.compare(text, options: .caseInsensitive) == .orderedSame }
        if !exact.isEmpty || query.exact { return exact }

        return candidates.filter { $0.label?.range(of: text, options: .caseInsensitive) != nil }
    }

    /// Whether an element passes the role and actionability filters.
    static func qualifies(_ element: Element, _ query: ElementQuery) -> Bool {
        if let role = query.role, !RoleNames.matches(role, role: element.role, subrole: element.subrole) {
            return false
        }
        if let identifier = query.identifier, element.identifier != identifier { return false }
        if query.actionableOnly, !ElementRules.isActionable(element) { return false }
        return true
    }
}
