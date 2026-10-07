//
//  Keystrokes.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Turning text into key events, and sending them to one app.
//

import CoreGraphics
import Foundation

/// Typing, by posting keyboard events to a process.
///
/// **To a process, not to the system.** `CGEventPostToPid` delivers to one
/// app whether or not it is frontmost — measured: text typed into a fixture
/// app while Finder was in front arrived intact, and nothing reached Finder.
/// A system-wide post would type into whatever the person is looking at.
///
/// **Text rides on the event's Unicode string**, not on key codes. Every
/// event carries virtual key 0 — which is `A` — and the characters to insert.
/// The header warns that "application frameworks may ignore the Unicode
/// string… and do their own translation based on the virtual keycode", which
/// would turn every character into an `a`. Measured: AppKit and Chrome both
/// honour the string, emoji included. An app that does not will type `aaaa`,
/// and the read-back after typing is what catches it.
public enum Keystrokes {

    /// How many UTF-16 units go in one event.
    ///
    /// Measured, not folklore: a 500-unit string in a single event arrived
    /// whole in an AppKit field, so there is no 20-character limit to work
    /// around. 100 keeps an event small for apps that handle each one on the
    /// main thread, and is still five times fewer events than one per key.
    public static let chunkSize = 100

    /// The strokes that type a piece of text.
    ///
    /// Newlines and tabs become the Return and Tab KEYS rather than
    /// characters: a field decides for itself what Return means — submit, new
    /// line — and inserting a raw `\n` character bypasses that decision.
    /// A chunk never ends between the two halves of a surrogate pair, which
    /// would deliver half an emoji as a replacement character.
    public static func strokes(for text: String, chunkSize: Int = Keystrokes.chunkSize) -> [Stroke] {
        var strokes: [Stroke] = []
        var pending: [UInt16] = []

        func flush() {
            guard !pending.isEmpty else { return }
            var start = 0
            while start < pending.count {
                var end = min(start + max(chunkSize, 2), pending.count)
                // A high surrogate at the end of a chunk belongs with the next.
                if end < pending.count, UTF16.isLeadSurrogate(pending[end - 1]) { end -= 1 }
                strokes.append(.text(Array(pending[start..<end])))
                start = end
            }
            pending.removeAll()
        }

        for scalar in text.unicodeScalars {
            switch scalar {
            case "\r":
                continue
            case "\n":
                flush()
                strokes.append(.key(Key.return))
            case "\t":
                flush()
                strokes.append(.key(Key.tab))
            default:
                pending.append(contentsOf: Array(String(scalar).utf16))
            }
        }
        flush()
        return strokes
    }

    /// Sends strokes to one process.
    static func post(_ strokes: [Stroke], to pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        for stroke in strokes {
            switch stroke {
            case .text(let units):
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }
                units.withUnsafeBufferPointer {
                    down.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress)
                    up.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress)
                }
                down.postToPid(pid)
                up.postToPid(pid)

            case .key(let code):
                CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)?.postToPid(pid)
                CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)?.postToPid(pid)
            }
        }
    }
}
