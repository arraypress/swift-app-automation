//
//  AppSession+Acting.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Pressing, setting, typing — and checking that it took.
//
//  EVERY ACTION RE-READS ITS ELEMENT FIRST, through ``AppSession/live(_:)``,
//  and refuses when the fingerprint no longer matches. The ref came from an
//  earlier read; in between, a list may have re-sorted or a sheet opened, and
//  acting on whatever now sits at that position is how the wrong thing gets
//  deleted.
//
//  AND EVERY ACTION THAT CAN BE CHECKED IS CHECKED. Accessibility's return
//  codes are not evidence: a web button returns success for a press it
//  ignored, and a field can accept a value and keep its old one. Where there
//  is something to read back, it is read back, and a mismatch is an error.
//

import AppKit
import ApplicationServices
import Foundation

public extension AppSession {

    // MARK: - Press

    /// Presses a button, checkbox, link, menu item or row.
    ///
    /// Uses `AXPress` where the element offers it, and focus-then-key where it
    /// does not — see ``PressMethod``.
    @discardableResult
    func press(_ ref: ElementRef) throws -> ActionResult {
        let (element, handle) = try live(ref)
        guard element.isEnabled else { throw AutomationError.disabled(element.described) }
        guard let method = element.pressMethod else {
            throw AutomationError.notPressable(element.described, actions: element.actions)
        }

        var note: String?
        switch method {
        case .press:
            let status = AXUIElementPerformAction(handle, kAXPressAction as CFString)
            switch status {
            case .success:
                break
            case .cannotComplete:
                // Measured against a button that opens a modal alert: the
                // call timed out with kAXErrorCannotComplete and the alert
                // WAS on screen. The header says as much — the app is busy
                // inside the action. So this is a press that worked.
                note = "\(app.name) did not answer in time — it usually means the press opened "
                    + "a dialog that is waiting for somebody"
            default:
                throw AXFailure.error(status, doing: "pressing \(element.described)")
            }

        case .focusSpace, .focusReturn:
            try focusElement(handle, described: element.described)
            Keystrokes.post([.key(method == .focusReturn ? Keystrokes.Key.return : Keystrokes.Key.space)],
                            to: app.pid)
        }

        // A checkbox's value says whether the press took. Anything else has
        // nothing to read, and is reported unverified rather than confirmed.
        var verified: Bool?
        var after: String?
        if element.role == "AXCheckBox" || element.role == "AXRadioButton", let before = element.value {
            let changed = Settle.until { currentValue(handle).map { $0 != before } ?? false }
            after = currentValue(handle)
            if changed { verified = true }
        }
        return ActionResult(element: element, action: "press", method: method,
                            verified: verified, valueAfter: after, note: note)
    }

    // MARK: - Set

    /// Sets a field's text, a checkbox's state or a slider's position — and
    /// reads it back.
    ///
    /// - Parameter value: The new value as text. A checkbox takes
    ///   `on`/`off`/`1`/`0`; a slider a number.
    /// - Throws: ``AutomationError/notApplied(expected:actual:)`` when the
    ///   element accepted the call and still reads something else.
    @discardableResult
    func setValue(_ ref: ElementRef, to value: String) throws -> ActionResult {
        let (element, handle) = try live(ref)
        guard !element.isSecure else { throw AutomationError.secureField(element.described) }
        guard element.isEnabled else { throw AutomationError.disabled(element.described) }
        guard AXRead.isSettable(kAXValueAttribute, of: handle) else {
            throw AutomationError.notSettable(element.described)
        }

        let isToggle = ["AXCheckBox", "AXSwitch"].contains(element.role) || element.subrole == "AXSwitch"
        let current = AXRead.attribute(kAXValueAttribute, of: handle).value as AnyObject?
        guard let typed = ValueCoercion.value(from: value, current: current, isToggle: isToggle) else {
            throw AutomationError.notSettable("\(element.described) does not take “\(value)” — it holds "
                + (isToggle ? "on or off" : "a number"))
        }

        let status = AXUIElementSetAttributeValue(handle, kAXValueAttribute as CFString, typed)
        guard status == .success else {
            throw AXFailure.error(status, doing: "setting \(element.described)")
        }

        // Chrome made the value readable 30 ms after the call returned; a
        // single immediate read would call that a refusal.
        let took = Settle.until { ValueCoercion.same(value, currentValue(handle), isToggle: isToggle) }
        let after = currentValue(handle)
        guard took else { throw AutomationError.notApplied(expected: value, actual: after) }
        return ActionResult(element: element, action: "set", verified: true, valueAfter: after)
    }

    // MARK: - Type

    /// Types text, as key events, into an element or whatever has focus.
    ///
    /// Use this rather than ``setValue(_:to:)`` when the app must see the
    /// typing happen — autocomplete, search-as-you-type, a field that
    /// validates per keystroke. Delivered to this app's process only, so it
    /// works with the app in the background and never types into whatever
    /// the person is looking at.
    ///
    /// - Parameters:
    ///   - text: What to type. Newlines press Return; tabs press Tab.
    ///   - ref: Where to type. `nil` types into the app's focused element.
    @discardableResult
    func type(_ text: String, into ref: ElementRef? = nil) throws -> ActionResult {
        let element: Element
        let handle: AXUIElement
        if let ref {
            (element, handle) = try live(ref)
            guard !element.isSecure else { throw AutomationError.secureField(element.described) }
            try focusElement(handle, described: element.described)
        } else {
            try ensureReadable()
            guard let focused = AXRead.element(
                AXRead.attribute(kAXFocusedUIElementAttribute, of: root).value as AnyObject?
            ) else { throw AutomationError.noSuchElement("a focused element in \(app.name)") }
            var reader = TreeReader(limits: .standard, root: root)
            reader.read(focused, path: path(to: focused) ?? [], levels: 0)
            guard let read = reader.elements.first else {
                throw AutomationError.noSuchElement("a focused element in \(app.name)")
            }
            guard !read.isSecure else { throw AutomationError.secureField(read.described) }
            (element, handle) = (read, focused)
        }

        let before = currentValue(handle)
        Keystrokes.post(Keystrokes.strokes(for: text), to: app.pid)

        // A field with a value to read can confirm the typing arrived. One
        // without — a canvas, a terminal — cannot, and says so with nil.
        guard ElementRules.acceptsText(element), before != nil else {
            return ActionResult(element: element, action: "type")
        }
        let typed = text.replacingOccurrences(of: "\r", with: "")
        let arrived = Settle.until { currentValue(handle).map { $0 != before && $0.contains(typed) } ?? false }
        let after = currentValue(handle)
        if arrived { return ActionResult(element: element, action: "type", verified: true, valueAfter: after) }
        if after == before { throw AutomationError.notApplied(expected: text, actual: after) }

        // It changed, but not into what was typed: an autocorrect, a field
        // that formats as you go, Return submitting the form. The typing
        // reached the app, and what the app did with it is reported as is.
        return ActionResult(element: element, action: "type", valueAfter: after,
                            note: "the field changed, but does not contain the text as typed")
    }

    // MARK: - Focus

    /// Brings the app forward and, given a ref, focuses that element or
    /// raises that window.
    ///
    /// The one action here that changes what the person sees. Everything else
    /// works with the app in the background, and should be preferred.
    @discardableResult
    func focus(_ ref: ElementRef? = nil) throws -> ActionResult? {
        try ensureReadable()
        // Checked by looking. `activate()` may refuse, and the alternative —
        // setting AXFrontmost — returned success and moved nothing.
        NSRunningApplication(processIdentifier: app.pid)?.activate()
        let forward = Settle.until { NSWorkspace.shared.frontmostApplication?.processIdentifier == app.pid }
        guard forward else { throw AutomationError.notFrontmost(app.name) }
        guard let ref else { return nil }

        let (element, handle) = try live(ref)
        if element.role == "AXWindow" {
            let status = AXUIElementPerformAction(handle, kAXRaiseAction as CFString)
            guard status == .success else { throw AXFailure.error(status, doing: "raising \(element.described)") }
            AXUIElementSetAttributeValue(handle, kAXMainAttribute as CFString, kCFBooleanTrue)
        } else {
            try focusElement(handle, described: element.described)
        }
        return ActionResult(element: element, action: "focus")
    }

    // MARK: - Pick

    /// Opens a pop-up button and chooses one of its items.
    ///
    /// - Parameter item: The item's title. Case and a trailing `…` are
    ///   ignored, as for menu paths.
    /// - Throws: ``AutomationError/noSuchMenuItem(_:)`` naming what the
    ///   pop-up does offer — after closing it again, so a wrong guess does not
    ///   leave a menu open over the app.
    @discardableResult
    func pick(_ item: String, in ref: ElementRef) throws -> ActionResult {
        let (element, handle) = try live(ref)
        guard element.isEnabled else { throw AutomationError.disabled(element.described) }
        guard element.actions.contains("AXPress") || element.actions.contains("AXShowMenu") else {
            throw AutomationError.notPressable(element.described, actions: element.actions)
        }

        let opening = element.actions.contains("AXPress") ? kAXPressAction : kAXShowMenuAction
        let status = AXUIElementPerformAction(handle, opening as CFString)
        guard status == .success else { throw AXFailure.error(status, doing: "opening \(element.described)") }

        var menu: AXUIElement?
        _ = Settle.until {
            menu = AXRead.children(of: handle).first {
                AXRead.text(AXRead.attribute(kAXRoleAttribute, of: $0).value as AnyObject?) == "AXMenu"
            }
            return menu != nil
        }
        guard let menu else { throw AutomationError.noSuchMenuItem("\(item) — \(element.described) opened no menu") }

        let items = AXRead.children(of: menu)
        let titles = items.map { AXRead.text(AXRead.attribute(kAXTitleAttribute, of: $0).value as AnyObject?) ?? "" }
        guard let index = titles.firstIndex(where: { MenuPath.matches(item, title: $0) }) else {
            AXUIElementPerformAction(menu, kAXCancelAction as CFString)
            let offered = titles.filter { !$0.isEmpty }.joined(separator: ", ")
            throw AutomationError.noSuchMenuItem("\(item) — \(element.described) offers \(offered)")
        }

        let chosen = AXUIElementPerformAction(items[index], kAXPressAction as CFString)
        guard chosen == .success else { throw AXFailure.error(chosen, doing: "choosing \(item)") }

        // A pop-up shows its choice as its value or its title, depending on
        // the app; either one naming the item confirms it.
        let shown: () -> String? = {
            let values = AXRead.values(of: handle, names: [kAXValueAttribute, kAXTitleAttribute])
            return AXRead.text(values[kAXValueAttribute]) ?? AXRead.text(values[kAXTitleAttribute])
        }
        let took = Settle.until { shown().map { MenuPath.matches(item, title: $0) } ?? false }
        return ActionResult(element: element, action: "pick", verified: took ? true : nil, valueAfter: shown())
    }

    // MARK: - Helpers

    /// An element's value now, as text. Never for a password field.
    internal func currentValue(_ handle: AXUIElement) -> String? {
        let values = AXRead.values(of: handle, names: [kAXSubroleAttribute, kAXValueAttribute])
        if AXRead.text(values[kAXSubroleAttribute]) == "AXSecureTextField" { return nil }
        return AXRead.text(values[kAXValueAttribute])
    }

    /// Gives an element keyboard focus.
    internal func focusElement(_ handle: AXUIElement, described: String) throws {
        let status = AXUIElementSetAttributeValue(handle, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        guard status == .success else { throw AXFailure.error(status, doing: "focusing \(described)") }
    }
}
