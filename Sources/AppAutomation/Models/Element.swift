//
//  Element.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One piece of another app's interface, read at a moment.
///
/// A value, not a handle: it holds what was true when the tree was read and
/// nothing changes it afterwards. To act on it, hand its ``ref`` back to
/// ``AppSession``, which checks the element is still the one that was read.
public struct Element: Sendable, Equatable, Codable {

    /// How to find this element again.
    public let ref: ElementRef

    /// How deep in the tree: windows and the menu bar are 1.
    public let depth: Int

    /// The Accessibility role: `AXButton`, `AXTextField`.
    public let role: String

    /// The refinement of the role, where there is one: `AXCloseButton`,
    /// `AXSecureTextField`, `AXOutlineRow`.
    public let subrole: String?

    /// What the app calls this kind of thing, localised: `button`, `text field`.
    public let roleDescription: String?

    /// The name a person would use for it, wherever the app put that name.
    ///
    /// Apps disagree on where. Measured across sixteen running apps, the label
    /// of a control came from its title, its description, a separate label
    /// element beside it (Finder's commonest, 78 of 186), its placeholder, or
    /// the text inside it. ``labelSource`` says which.
    public let label: String?

    /// Where ``label`` came from.
    public let labelSource: LabelSource

    /// The element's value, as text: a field's contents, a checkbox's `0` or
    /// `1`, a slider's position. Never read for a password field.
    public let value: String?

    /// A developer-assigned identifier, when the app set one.
    public let identifier: String?

    /// The tooltip.
    public let help: String?

    /// Where it is on screen, top-left origin.
    public let frame: Frame?

    /// Whether it accepts input. A disabled button is still in the tree.
    public let isEnabled: Bool

    /// Whether it has keyboard focus.
    public let isFocused: Bool

    /// Whether it is a password field.
    public let isSecure: Bool

    /// Whether the app reports it selected: a row in a list, a tab, a cell.
    ///
    /// Accessibility's `AXSelected`, and only that — a checkbox that is on
    /// says so in its ``value`` (`1`), not here.
    public let isSelected: Bool

    /// What can be done to it, by Accessibility name: `AXPress`, `AXShowMenu`.
    ///
    /// **Believe this list over the return code of an action.** A button in
    /// Chrome's web content offers only `AXShowMenu` and `AXScrollToVisible`,
    /// and asking it to `AXPress` anyway returns success and does nothing.
    public let actions: [String]

    /// An element from its parts. Built by ``AppSession`` from a live read;
    /// public so tests and fakes can make one.
    public init(
        ref: ElementRef,
        depth: Int,
        role: String,
        subrole: String? = nil,
        roleDescription: String? = nil,
        label: String? = nil,
        labelSource: LabelSource = .none,
        value: String? = nil,
        identifier: String? = nil,
        help: String? = nil,
        frame: Frame? = nil,
        isEnabled: Bool = true,
        isFocused: Bool = false,
        isSecure: Bool = false,
        isSelected: Bool = false,
        actions: [String] = []
    ) {
        self.ref = ref
        self.depth = depth
        self.role = role
        self.subrole = subrole
        self.roleDescription = roleDescription
        self.label = label
        self.labelSource = labelSource
        self.value = value
        self.identifier = identifier
        self.help = help
        self.frame = frame
        self.isEnabled = isEnabled
        self.isFocused = isFocused
        self.isSecure = isSecure
        self.isSelected = isSelected
        self.actions = actions
    }
}
