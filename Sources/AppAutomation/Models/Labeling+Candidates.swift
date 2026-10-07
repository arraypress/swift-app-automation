//
//  Labeling+Candidates.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension Labeling {

    /// Everything an element might be called, as read from it.
    public struct Candidates: Sendable, Equatable {

        /// The Accessibility role, which decides whether ``value`` may count.
        public var role: String

        /// The role refinement — the only name a window's close button has.
        public var subrole: String?

        /// `AXTitle`.
        public var title: String?

        /// `AXDescription` — what the app tells VoiceOver.
        public var description: String?

        /// The value or title of the element named by `AXTitleUIElement`.
        public var titledBy: String?

        /// `AXPlaceholderValue`.
        public var placeholder: String?

        /// Text found inside the element, for a cell or row with no name of
        /// its own.
        public var text: String?

        /// `AXHelp` — the tooltip.
        public var help: String?

        /// `AXValue`, as text.
        public var value: String?

        /// `AXIdentifier`.
        public var identifier: String?

        /// Candidates from whatever was read; anything absent is `nil`.
        public init(
            role: String,
            subrole: String? = nil,
            title: String? = nil,
            description: String? = nil,
            titledBy: String? = nil,
            placeholder: String? = nil,
            text: String? = nil,
            help: String? = nil,
            value: String? = nil,
            identifier: String? = nil
        ) {
            self.role = role
            self.subrole = subrole
            self.title = title
            self.description = description
            self.titledBy = titledBy
            self.placeholder = placeholder
            self.text = text
            self.help = help
            self.value = value
            self.identifier = identifier
        }
    }
}
