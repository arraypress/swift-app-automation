//
//  AutomationError.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong reading or driving another app.
public enum AutomationError: Error, Equatable, Sendable, LocalizedError {

    /// This process is not a trusted Accessibility client.
    ///
    /// The grant belongs to whatever launched the process — the terminal, not
    /// the binary — so a tool run from Terminal is trusted exactly when
    /// Terminal is.
    case notTrusted

    /// The screen is locked, and while it is no window is visible to
    /// Accessibility and no app can come forward.
    case screenLocked

    /// The app was asked to come forward and did not.
    ///
    /// Activation is cooperative since macOS 14: an app comes forward only
    /// when the active app lets it. Measured, `NSRunningApplication.activate()`
    /// returned `false`, and setting `AXFrontmost` returned SUCCESS — and in
    /// neither case did the app move. Checked by looking, never assumed.
    case notFrontmost(String)

    /// No running app matches.
    case noSuchApp(String)

    /// More than one running app matches, and guessing would act on the wrong
    /// one. Carries the candidates' names.
    case ambiguousApp(String, [String])

    /// The app is hidden, and a hidden app answers no questions about its
    /// windows: the read fails outright rather than coming back empty.
    case appHidden(String)

    /// The app is running with no windows at all.
    case noWindows(String)

    /// The app has windows, but on another Space.
    ///
    /// Measured: Notes with six real windows on another desktop reported
    /// **zero** through Accessibility. Without this case that reads as "Notes
    /// has nothing open", which is false.
    case windowsOnAnotherSpace(String, count: Int)

    /// No window with that title.
    case noSuchWindow(String)

    /// Nothing in the interface matches.
    case noSuchElement(String)

    /// More than one element matches, and acting on one of them would be a
    /// coin toss. Carries the candidates so the caller can choose by ref.
    case ambiguous(String, [Element])

    /// The element at that ref is no longer the one that was read.
    ///
    /// A list re-sorted, a window closed, a sheet opened. Acting anyway would
    /// press whatever now sits at that position — which is how the wrong
    /// button gets pressed.
    case stale(ElementRef)

    /// The element offers no way to be pressed.
    case notPressable(String, actions: [String])

    /// The element is disabled.
    ///
    /// A disabled button is still in the tree and still accepts the press
    /// call — and nothing happens. Refused up front, because "pressed, and
    /// nothing happened" is indistinguishable from success afterwards.
    case disabled(String)

    /// The element's value cannot be set.
    case notSettable(String)

    /// The element is a password field.
    ///
    /// Refused for reading and writing both. A secret typed through this
    /// library would have been a command-line argument or a log line first.
    case secureField(String)

    /// The change was made and did not take.
    ///
    /// The app accepted the call and the value read back is something else.
    /// Reported rather than ignored: a field that silently refused input looks
    /// exactly like one that took it, until somebody reads the result.
    case notApplied(expected: String, actual: String?)

    /// No menu item at that path.
    case noSuchMenuItem(String)

    /// The menu item exists and is disabled.
    case menuItemDisabled(String)

    /// The app did not answer in time — usually busy or hung.
    case timedOut(String)

    /// The Accessibility API refused, with its own code.
    case failed(String, code: Int32)

    /// A sentence a person can act on.
    public var errorDescription: String? {
        switch self {
        case .notTrusted:
            "This process is not allowed to control other apps — grant Accessibility to your "
                + "terminal in System Settings ▸ Privacy & Security ▸ Accessibility"
        case .screenLocked:
            "The screen is locked — no app's windows can be read or driven until it is unlocked"
        case .notFrontmost(let name):
            "\(name) did not come forward — macOS lets an app activate only when the active app yields"
        case .noSuchApp(let name):
            "No running app matches \(name)"
        case .ambiguousApp(let name, let candidates):
            "\(name) matches \(candidates.count) apps: \(candidates.joined(separator: ", "))"
        case .appHidden(let name):
            "\(name) is hidden — its windows cannot be read until it is shown"
        case .noWindows(let name):
            "\(name) has no windows open"
        case .windowsOnAnotherSpace(let name, let count):
            "\(name) has \(count) window\(count == 1 ? "" : "s") on another Space, which "
                + "Accessibility cannot see"
        case .noSuchWindow(let title):
            "No window titled \(title)"
        case .noSuchElement(let what):
            "Nothing matches \(what)"
        case .ambiguous(let what, let candidates):
            "\(what) matches \(candidates.count) elements"
        case .stale(let ref):
            "The element at \(ref) has changed since it was read"
        case .notPressable(let what, let actions):
            actions.isEmpty
                ? "\(what) cannot be pressed"
                : "\(what) cannot be pressed — it offers \(actions.joined(separator: ", "))"
        case .disabled(let what):
            "\(what) is disabled"
        case .notSettable(let what):
            "\(what) does not accept a value"
        case .secureField(let what):
            "\(what) is a password field — refused"
        case .notApplied(let expected, let actual):
            "The value did not take: asked for \(expected), it reads \(actual ?? "nothing")"
        case .noSuchMenuItem(let path):
            "No menu item at \(path)"
        case .menuItemDisabled(let path):
            "\(path) is disabled"
        case .timedOut(let what):
            "\(what) did not answer in time"
        case .failed(let what, let code):
            "\(what) failed (Accessibility error \(code))"
        }
    }
}
