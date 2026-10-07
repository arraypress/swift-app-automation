//
//  AppSession+ReadLimits.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension AppSession {

    /// How much of a tree to read before stopping.
    ///
    /// Limits exist because some trees do not end: a web page with infinite
    /// scroll, a table with a hundred thousand rows. Hitting one is recorded
    /// on the ``Snapshot`` as ``Snapshot/isTruncated``, never silently.
    public struct ReadLimits: Sendable, Equatable {

        /// Stop after this many elements.
        public var maxElements: Int

        /// Do not descend below this depth.
        public var maxDepth: Int

        /// Limits, defaulting to ``standard``'s.
        public init(maxElements: Int = 3000, maxDepth: Int = 60) {
            self.maxElements = maxElements
            self.maxDepth = maxDepth
        }

        /// 3,000 elements, 60 deep. Contacts read whole was 760, Chrome on a
        /// simple page 350; 3,000 leaves room for a busy web page without
        /// letting a runaway list take minutes.
        public static let standard = ReadLimits()
    }
}
