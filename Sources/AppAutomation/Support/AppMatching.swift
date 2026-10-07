//
//  AppMatching.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Which running app a name means.
//

import Foundation

/// Matching what a caller typed against running apps.
public enum AppMatching {

    /// The apps a query names, best match only.
    ///
    /// Tried in order, and the first rule that finds anything wins:
    /// a pid; a bundle identifier, exactly; a name, exactly; a name's start;
    /// anywhere in a name. Case is ignored throughout. So `Notes` means Notes
    /// and not Sticky Notes, while `chrome` still finds Google Chrome — and
    /// `Google` with two Google apps running finds both, which the caller is
    /// told rather than handed whichever came first.
    public static func select(_ query: String, from apps: [RunningApp]) -> [RunningApp] {
        let wanted = query.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return [] }

        if let pid = Int32(wanted) {
            return apps.filter { $0.pid == pid }
        }

        let rules: [(RunningApp) -> Bool] = [
            { $0.bundleID?.compare(wanted, options: .caseInsensitive) == .orderedSame },
            { $0.name.compare(wanted, options: .caseInsensitive) == .orderedSame },
            { $0.name.range(of: wanted, options: [.caseInsensitive, .anchored]) != nil },
            { $0.name.range(of: wanted, options: .caseInsensitive) != nil },
        ]
        for rule in rules {
            let found = apps.filter(rule)
            if !found.isEmpty { return found }
        }
        return []
    }
}
