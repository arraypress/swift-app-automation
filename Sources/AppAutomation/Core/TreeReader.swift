//
//  TreeReader.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Walking a live interface into a flat list of values.
//

import ApplicationServices
import Foundation

/// A depth-first walk of a live element and everything under it.
///
/// Keeps the live handles beside the values, index for index, so a caller
/// that finds what it wants in the values can act on the handle without a
/// second walk.
struct TreeReader {

    /// Roles named by the text inside them when they have no name of their own.
    static let namedByContents: Set<String> = [
        "AXRow", "AXCell", "AXButton", "AXMenuButton", "AXLink", "AXRadioButton", "AXCheckBox",
    ]

    /// How far below an element its naming text may be.
    ///
    /// Four, because a Finder sidebar row is row ▸ cell ▸ text and a
    /// Contacts list row nests one group deeper. Beyond that the text belongs
    /// to something else inside the element — a row's second column — not to
    /// the element itself.
    static let namingDepth = 4

    let limits: AppSession.ReadLimits

    /// The app's own element, which is never descended into again.
    ///
    /// An app can list ITSELF among its children — measured on every app
    /// while the screen was locked — and a walk that follows it reads the
    /// same element until the limits stop it: Finder came back as 30,000
    /// copies of itself and not one control.
    let root: AXUIElement?

    private(set) var elements: [Element] = []
    private(set) var handles: [AXUIElement] = []
    private(set) var isTruncated = false

    init(limits: AppSession.ReadLimits, root: AXUIElement? = nil) {
        self.limits = limits
        self.root = root
    }

    /// Reads an element and its descendants.
    ///
    /// - Parameters:
    ///   - element: Where to start.
    ///   - path: Its path from the top level down — see ``ElementRef``.
    ///   - levels: How many levels below it to read. `nil` uses the limits.
    mutating func read(_ element: AXUIElement, path: [Int], levels: Int? = nil) {
        // A depth a caller chose is not a truncation of what it asked for;
        // only the limits cutting a tree short is.
        walk(element, path: path, remaining: levels ?? limits.maxDepth, cutIsTruncation: levels == nil)
    }

    private mutating func walk(_ element: AXUIElement, path: [Int], remaining: Int, cutIsTruncation: Bool) {
        guard elements.count < limits.maxElements else {
            isTruncated = true
            return
        }

        let values = AXRead.values(of: element)
        let titledBy = AXRead.element(values[kAXTitleUIElementAttribute]).flatMap(Self.text(of:))
        let index = elements.count

        elements.append(ElementBuilder.element(
            from: values,
            path: path,
            actions: AXRead.actions(of: element),
            titledBy: titledBy,
            text: nil
        ))
        handles.append(element)

        let children = (values[kAXChildrenAttribute] as? [AXUIElement]) ?? []
        if remaining > 0 {
            for (offset, child) in children.enumerated()
            where !CFEqual(child, element) && !(root.map { CFEqual(child, $0) } ?? false) {
                walk(child, path: path + [offset], remaining: remaining - 1, cutIsTruncation: cutIsTruncation)
            }
        } else if !children.isEmpty, cutIsTruncation {
            isTruncated = true
        }

        let read = elements[index]
        if read.label == nil, Self.namedByContents.contains(read.role),
           let text = Self.namingText(in: elements[(index + 1)...], below: read.depth) {
            elements[index] = ElementBuilder.named(read, text: text)
        }
    }

    /// The first static text within ``namingDepth`` levels of an element.
    ///
    /// Static text only — not a button's label. A row containing a Delete
    /// button must not be called "Delete".
    static func namingText(in descendants: ArraySlice<Element>, below depth: Int) -> String? {
        descendants.first {
            $0.depth <= depth + namingDepth
                && $0.role == "AXStaticText"
                && $0.label != nil
        }?.label
    }

    /// The text of a label element named by `AXTitleUIElement`.
    static func text(of element: AXUIElement) -> String? {
        let values = AXRead.values(of: element, names: [kAXValueAttribute, kAXTitleAttribute])
        return Labeling.clean(AXRead.text(values[kAXValueAttribute]) ?? AXRead.text(values[kAXTitleAttribute]))
    }
}
