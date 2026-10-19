//
//  WaitRules.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  What a reading means for a condition, decided from values.
//

import Foundation

/// The rules of a wait that need no live app: what a query found, what a
/// reading shows, and whether a requirement holds.
///
/// Pure, so a fake tree that changes over time can drive every one of them.
public enum WaitRules {

    /// What a query finds in a read tree.
    ///
    /// - Parameter truncated: Whether the read stopped at its limits. Nothing
    ///   found in a tree that was cut short is not "gone" — the element may be
    ///   past the cut — so it is ``WaitObservation/unreadable(_:)``.
    public static func observe(_ query: ElementQuery, in elements: [Element], truncated: Bool = false) -> WaitObservation {
        let matches = QueryMatching.select(query, from: elements)
        let what = AppSession.describe(query)
        switch matches.count {
        case 0 where truncated:
            return .unreadable("the read stopped at \(elements.count) elements without finding \(what)")
        case 0:
            return .absent("nothing matches \(what)")
        case 1:
            return .present(matches[0])
        default:
            return .ambiguous(matches)
        }
    }

    /// The part of an observation a condition can see.
    public static func reading(_ observation: WaitObservation) -> WaitReading {
        switch observation {
        case .present(let element):
            return WaitReading(
                state: .present,
                ref: element.ref,
                kind: element.kind,
                label: element.label,
                value: element.value,
                isEnabled: element.isEnabled,
                isSelected: isSelected(element)
            )
        case .absent(let reason):
            return WaitReading(state: .absent, reason: reason)
        case .ambiguous(let elements):
            return WaitReading(state: .ambiguous, candidates: elements.map(\.ref),
                               reason: "\(elements.count) elements match")
        case .unreadable(let reason):
            return WaitReading(state: .unreadable, reason: reason)
        }
    }

    /// Whether a requirement holds for a reading.
    ///
    /// Everything but ``WaitRequirement/gone`` needs exactly one element
    /// there. Several is never "exists": a wait that said yes to two "Save"
    /// buttons would send the next command to press one of them, which is
    /// refused.
    public static func satisfies(_ requirement: WaitRequirement, _ reading: WaitReading) -> Bool {
        if requirement == .gone { return reading.state == .absent }
        guard reading.state == .present else { return false }
        switch requirement {
        case .exists, .gone:
            return true
        case .valueEquals(let text):
            return reading.value == text
        case .valueContains(let text):
            return reading.value?.contains(text) ?? false
        case .enabled:
            return reading.isEnabled == true
        case .disabled:
            return reading.isEnabled == false
        case .selected:
            return reading.isSelected == true
        }
    }

    /// Whether a requirement reads the element's value.
    ///
    /// Those are refused on a password field: whether a wait succeeded would
    /// otherwise answer "is the password this?" one guess at a time.
    public static func readsValue(_ requirement: WaitRequirement) -> Bool {
        switch requirement {
        case .valueEquals, .valueContains: return true
        default: return false
        }
    }

    /// Whether an element is selected: `AXSelected`, or a checkbox or radio
    /// button that is on — which says so in its value, `1`, not in
    /// `AXSelected`. A tab is a radio button to Accessibility.
    public static func isSelected(_ element: Element) -> Bool {
        if element.isSelected { return true }
        return ["AXCheckBox", "AXRadioButton"].contains(element.role) && element.value == "1"
    }

    /// `button “Save” is enabled`, for messages.
    public static func describe(_ condition: WaitCondition) -> String {
        let subject: String
        switch condition.subject {
        case .element(let query, .window(let title)):
            subject = "\(AppSession.describe(query)) in window “\(title)”"
        case .element(let query, .menuBar):
            subject = "\(AppSession.describe(query)) in the menu bar"
        case .element(let query, _):
            subject = AppSession.describe(query)
        case .ref(let ref):
            subject = ref.description
        case .window(let title):
            subject = "window “\(title)”"
        }
        switch condition.requirement {
        case .exists: return "\(subject) exists"
        case .gone: return "\(subject) is gone"
        case .valueEquals(let text): return "\(subject) has the value “\(text)”"
        case .valueContains(let text): return "\(subject) has a value containing “\(text)”"
        case .enabled: return "\(subject) is enabled"
        case .disabled: return "\(subject) is disabled"
        case .selected: return "\(subject) is selected"
        }
    }
}
