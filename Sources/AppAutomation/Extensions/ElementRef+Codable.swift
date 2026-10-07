//
//  ElementRef+Codable.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  A ref encodes as the string a caller copies, not as an object.
//

import Foundation

extension ElementRef: Codable {

    /// Reads `"0.3.1#9f2c"`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let ref = RefCodec.parse(text) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "\(text) is not an element ref"
            )
        }
        self = ref
    }

    /// Writes `"0.3.1#9f2c"` — the form every command accepts back, so a
    /// script can lift it out of JSON and pass it on without assembling it.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(RefCodec.format(self))
    }
}
