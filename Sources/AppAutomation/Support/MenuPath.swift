//
//  MenuPath.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Reading `File > New Folder`.
//

import Foundation

/// The written form of a menu path.
public enum MenuPath {

    /// The separators accepted between titles.
    ///
    /// `>` because it is on every keyboard, and `▸` and `→` because those are
    /// how menu paths are written in documentation and help text, which is
    /// where a caller will have copied one from.
    static let separators: Set<Character> = [">", "▸", "→"]

    /// `File > New Folder` → `["File", "New Folder"]`.
    ///
    /// Empty steps are dropped, so a stray separator at either end does not
    /// produce a step called "" that matches nothing.
    public static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: { separators.contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// `["File", "New Folder"]` → `File > New Folder`.
    public static func format(_ path: [String]) -> String {
        path.joined(separator: " > ")
    }

    /// Whether a menu title answers to a step a caller wrote.
    ///
    /// Ignores case, and ignores a trailing ellipsis either way: menus write
    /// `Save As…` with the single character `…`, people type `Save As...` or
    /// just `Save As`, and all three mean the same item.
    public static func matches(_ step: String, title: String) -> Bool {
        stripped(step).compare(stripped(title), options: .caseInsensitive) == .orderedSame
    }

    /// A title without its trailing ellipsis or surrounding space.
    static func stripped(_ title: String) -> String {
        var value = title.trimmingCharacters(in: .whitespaces)
        if value.hasSuffix("…") { value.removeLast() }
        while value.hasSuffix(".") { value.removeLast() }
        return value.trimmingCharacters(in: .whitespaces)
    }
}
