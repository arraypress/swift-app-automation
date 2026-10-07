//
//  ElementRef+Parsing.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension ElementRef: CustomStringConvertible {

    /// Reads `0.3.1#9f2c`, or `nil` when the text is not a ref.
    public init?(_ text: String) {
        guard let ref = RefCodec.parse(text) else { return nil }
        self = ref
    }

    /// `0.3.1#9f2c`.
    public var description: String { RefCodec.format(self) }
}
