//
//  Snapshot.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An app's interface, read at one moment, as a flat list.
///
/// Flat rather than nested: each element carries its ``Element/depth`` and
/// its ``Element/ref`` (which is its path), so the tree can be rebuilt by
/// anyone who wants it, and everybody else — a search, a table, a language
/// model paying by the token — gets one row per element without walking
/// anything.
public struct Snapshot: Sendable, Equatable, Codable {

    /// Whose interface this is.
    public let app: RunningApp

    /// Every element read, in tree order — a parent before its children.
    public let elements: [Element]

    /// Whether the read stopped at ``AppSession/ReadLimits`` before the tree
    /// ended.
    ///
    /// Recorded rather than implied: a list that was cut short and a list
    /// that ended look identical without it.
    public let isTruncated: Bool

    /// A snapshot from its parts. Built by ``AppSession/snapshot(_:limits:)``.
    public init(app: RunningApp, elements: [Element], isTruncated: Bool) {
        self.app = app
        self.elements = elements
        self.isTruncated = isTruncated
    }
}
