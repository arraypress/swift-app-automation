//
//  RefCodec.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Writing an element's ref out, and reading one back.
//

import Foundation

/// The `0.3.1#9f2c` form of an ``ElementRef``.
public enum RefCodec {

    /// The fingerprint for a role and label: four hex digits.
    ///
    /// FNV-1a over `role` and `label`, folded to 16 bits. Four digits because
    /// the ref is something a person or a model copies from one command into
    /// the next, and the job is only to notice that the element at a position
    /// changed — two different elements landing on the same path AND the same
    /// fingerprint is a 1-in-65,536 coincidence on top of a re-layout.
    ///
    /// Not `Hasher`: Swift seeds it per process, so a ref printed by one run
    /// would never match in the next.
    public static func fingerprint(role: String, label: String?) -> String {
        var hash: UInt32 = 0x811C_9DC5
        for byte in Array("\(role)\u{1F}\(label ?? "")".utf8) {
            hash ^= UInt32(byte)
            hash = hash &* 0x0100_0193
        }
        let folded = UInt16(truncatingIfNeeded: hash ^ (hash >> 16))
        return String(format: "%04x", folded)
    }

    /// `0.3.1#9f2c`.
    public static func format(_ ref: ElementRef) -> String {
        ref.path.map(String.init).joined(separator: ".") + "#" + ref.fingerprint
    }

    /// Reads a ref, or `nil` when the text is not shaped like one.
    ///
    /// Strict on purpose: the same argument position takes a label, and a
    /// button called `3.1` must not be mistaken for a path.
    public static func parse(_ text: String) -> ElementRef? {
        let parts = text.split(separator: "#", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let fingerprint = String(parts[1])
        guard fingerprint.count == 4,
              fingerprint.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else { return nil }

        let steps = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        var path: [Int] = []
        for step in steps {
            guard !step.isEmpty, step.allSatisfy(\.isASCII), let index = Int(step), index >= 0 else {
                return nil
            }
            path.append(index)
        }
        return ElementRef(path: path, fingerprint: fingerprint)
    }
}
