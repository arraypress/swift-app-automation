//
//  RuleTests.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  The parts that need no app. Every rule here decides something about
//  values — what an element is called, which of several a query means, how
//  a press is delivered — and each was measured against a real interface
//  before it was written down. Anything driving a live app is in
//  `LiveTests`, which skips itself unless asked.
//

import XCTest
@testable import AppAutomation

/// An element built by hand, with only the fields a test cares about.
func element(
    _ role: String,
    _ label: String? = nil,
    subrole: String? = nil,
    value: String? = nil,
    path: [Int] = [0],
    actions: [String] = [],
    source: LabelSource = .title,
    enabled: Bool = true,
    secure: Bool = false
) -> Element {
    Element(
        ref: ElementRef(path: path, fingerprint: RefCodec.fingerprint(role: role, label: label)),
        depth: path.count,
        role: role,
        subrole: subrole,
        label: label,
        labelSource: label == nil ? .none : source,
        value: value,
        isEnabled: enabled,
        isSecure: secure,
        actions: actions
    )
}

final class LabelingTests: XCTestCase {

    func testATitleBeatsEverythingElse() {
        let found = Labeling.label(from: .init(
            role: "AXButton", title: "Save", description: "Save the document", help: "⌘S"
        ))
        XCTAssertEqual(found.label, "Save")
        XCTAssertEqual(found.source, .title)
    }

    func testAnIconButtonIsNamedByItsDescription() {
        // Mail's toolbar: 97 controls named only for VoiceOver.
        let found = Labeling.label(from: .init(role: "AXButton", description: "Reply"))
        XCTAssertEqual(found.label, "Reply")
        XCTAssertEqual(found.source, .description)
    }

    func testAFieldIsNotNamedByWhatSomebodyTypedIntoIt() {
        // Named by its value, the field called "Name" would become "Ada" the
        // moment it was filled in, and every instruction against it would
        // stop matching.
        let found = Labeling.label(from: .init(role: "AXTextField", placeholder: "Name", value: "Ada"))
        XCTAssertEqual(found.label, "Name")

        let bare = Labeling.label(from: .init(role: "AXTextField", value: "Ada"))
        XCTAssertNil(bare.label)
    }

    func testStaticTextIsNamedByItsValue() {
        let found = Labeling.label(from: .init(role: "AXStaticText", value: "Count: 3"))
        XCTAssertEqual(found.label, "Count: 3")
        XCTAssertEqual(found.source, .value)
    }

    func testAppKitsGeneratedIdentifiersAreNotNames() {
        // 1,195 of about 4,400 identifiers measured were `_NS:<n>`.
        XCTAssertNil(Labeling.label(from: .init(role: "AXButton", identifier: "_NS:42")).label)
        XCTAssertEqual(
            Labeling.label(from: .init(role: "AXButton", identifier: "ConversationList")).label,
            "ConversationList"
        )
    }

    func testWindowButtonsAreNamedBySubrole() {
        let found = Labeling.label(from: .init(role: "AXButton", subrole: "AXCloseButton"))
        XCTAssertEqual(found.label, "close-button")
        XCTAssertEqual(found.source, .subrole)
    }

    func testLabelsAreFlattenedToOneLine() {
        // A newline in a label breaks every one-row-per-element output.
        let found = Labeling.label(from: .init(role: "AXButton", title: "  Save\n  as PDF  "))
        XCTAssertEqual(found.label, "Save as PDF")
        XCTAssertNil(Labeling.label(from: .init(role: "AXButton", title: " \n ")).label)
    }
}

final class RoleNameTests: XCTestCase {

    func testFriendlyNames() {
        XCTAssertEqual(RoleNames.kind(role: "AXButton"), "button")
        XCTAssertEqual(RoleNames.kind(role: "AXCheckBox"), "checkbox")
        XCTAssertEqual(RoleNames.kind(role: "AXTextField"), "text-field")
        XCTAssertEqual(RoleNames.kind(role: "AXDisclosureTriangle"), "disclosure-triangle")
        XCTAssertEqual(RoleNames.kind(role: "AXTextField", subrole: "AXSecureTextField"), "secure-field")
        XCTAssertEqual(RoleNames.kind(role: "AXRadioButton", subrole: "AXTabButton"), "tab")
    }

    func testEitherFormMatches() {
        XCTAssertTrue(RoleNames.matches("button", role: "AXButton", subrole: nil))
        XCTAssertTrue(RoleNames.matches("AXButton", role: "AXButton", subrole: nil))
        XCTAssertTrue(RoleNames.matches("BUTTON", role: "AXButton", subrole: nil))
        XCTAssertFalse(RoleNames.matches("checkbox", role: "AXButton", subrole: nil))
    }

    func testASearchFieldIsATextFieldButAPasswordFieldIsNot() {
        XCTAssertTrue(RoleNames.matches("text-field", role: "AXTextField", subrole: "AXSearchField"))
        XCTAssertTrue(RoleNames.matches("search-field", role: "AXTextField", subrole: "AXSearchField"))
        // Asking for "a text field" should never land on the password.
        XCTAssertFalse(RoleNames.matches("text-field", role: "AXTextField", subrole: "AXSecureTextField"))
    }
}

final class RefTests: XCTestCase {

    func testRoundTrip() {
        let ref = ElementRef(path: [0, 3, 12], fingerprint: RefCodec.fingerprint(role: "AXButton", label: "Save"))
        XCTAssertEqual(ElementRef(ref.description), ref)
        XCTAssertTrue(ref.description.hasPrefix("0.3.12#"))
    }

    func testTheFingerprintIsStableAcrossProcesses() throws {
        // Swift's Hasher is seeded per process; a ref printed by one run has
        // to match in the next. Pinned to a value computed outside Swift
        // (FNV-1a in Python), so this cannot pass by agreeing with itself.
        let pinned = RefCodec.fingerprint(role: "AXButton", label: "Increment")
        XCTAssertEqual(pinned, "5c35")
        XCTAssertNotEqual(pinned, RefCodec.fingerprint(role: "AXButton", label: "Decrement"))
        XCTAssertNotEqual(pinned, RefCodec.fingerprint(role: "AXCheckBox", label: "Increment"))
    }

    func testLabelsThatLookLikePathsAreNotRefs() {
        // The same argument takes a label, and a button called "3.1" exists.
        for text in ["3.1", "Save", "0.1#", "0.1#12345", "0.1#ABCD", "a.1#abcd", "#abcd", "0..1#abcd", "-1#abcd"] {
            XCTAssertNil(ElementRef(text), text)
        }
        XCTAssertNotNil(ElementRef("0#abcd"))
    }

    func testARefEncodesAsTheStringACallerCopies() throws {
        let ref = ElementRef(path: [1, 2], fingerprint: "9f2c")
        let data = try JSONEncoder().encode([ref])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"["1.2#9f2c"]"#)
        XCTAssertEqual(try JSONDecoder().decode([ElementRef].self, from: data), [ref])
    }
}

final class QueryTests: XCTestCase {

    let window = [
        element("AXButton", "Save", path: [0, 1]),
        element("AXButton", "Save As…", path: [0, 2]),
        element("AXButton", "Delete", path: [0, 3]),
        element("AXStaticText", "Save your work", path: [0, 4], source: .value),
        element("AXTextField", "Name", path: [0, 5], source: .placeholder),
    ]

    func testAnExactLabelBeatsAPartialOne() {
        // "Save" means Save, not "two matches — choose".
        let found = QueryMatching.select(ElementQuery("save"), from: window)
        XCTAssertEqual(found.map(\.label), ["Save"])
    }

    func testPartialMatchesAllCountWhenNothingIsExact() {
        let found = QueryMatching.select(ElementQuery("sav"), from: window)
        XCTAssertEqual(found.count, 3)
    }

    func testExactRefusesPartials() {
        XCTAssertTrue(QueryMatching.select(ElementQuery("sav", exact: true), from: window).isEmpty)
    }

    func testRoleNarrows() {
        let found = QueryMatching.select(ElementQuery("sav", role: "button"), from: window)
        XCTAssertEqual(found.map(\.label), ["Save", "Save As…"])
    }

    func testActionableOnlyDropsText() {
        let found = QueryMatching.select(ElementQuery("save your", actionableOnly: true), from: window)
        XCTAssertTrue(found.isEmpty)
    }

    func testNoTextMeansEveryElementOfTheRole() {
        XCTAssertEqual(QueryMatching.select(ElementQuery(role: "text-field"), from: window).count, 1)
    }
}

final class ElementRuleTests: XCTestCase {

    func testNativeControlsArePressedByTheirAction() {
        XCTAssertEqual(ElementRules.pressMethod(role: "AXButton", actions: ["AXPress"]), .press)
        XCTAssertEqual(ElementRules.pressMethod(role: "AXCell", actions: ["AXPress"]), .press)
    }

    func testWebControlsArePressedFromTheKeyboard() {
        // Chrome, measured: no AXPress, and calling it anyway returns success
        // and does nothing.
        let web = ["AXShowMenu", "AXScrollToVisible"]
        XCTAssertEqual(ElementRules.pressMethod(role: "AXButton", actions: web), .focusSpace)
        XCTAssertEqual(ElementRules.pressMethod(role: "AXCheckBox", actions: web), .focusSpace)
        // Space on a focused link scrolls the page.
        XCTAssertEqual(ElementRules.pressMethod(role: "AXLink", actions: web), .focusReturn)
    }

    func testThingsThatCannotBePressed() {
        XCTAssertNil(ElementRules.pressMethod(role: "AXStaticText", actions: []))
        XCTAssertNil(ElementRules.pressMethod(role: "AXTextField", actions: ["AXConfirm"]))
    }

    func testPasswordFieldsAreRecognisedBySubrole() {
        XCTAssertTrue(ElementRules.isSecure(role: "AXTextField", subrole: "AXSecureTextField"))
        XCTAssertFalse(ElementRules.isSecure(role: "AXTextField", subrole: "AXSearchField"))
    }

    func testTheSummaryKeepsControlsAndNamesAndDropsScaffolding() {
        XCTAssertTrue(ElementRules.isWorthShowing(element("AXButton")))
        XCTAssertTrue(ElementRules.isWorthShowing(element("AXWindow")))
        XCTAssertTrue(ElementRules.isWorthShowing(element("AXStaticText", "Hello", source: .value)))
        XCTAssertFalse(ElementRules.isWorthShowing(element("AXGroup")))
        XCTAssertFalse(ElementRules.isWorthShowing(element("AXGroup", "SidebarContainer", source: .identifier)))
        XCTAssertTrue(ElementRules.isWorthShowing(element("AXGroup", "Favourites", source: .description)))
    }

    func testRowsAreNamedByTheTextInsideThemNotByTheirButtons() {
        // A row holding a Delete button must not be called "Delete".
        let descendants: ArraySlice<Element> = [
            element("AXCell", nil, path: [0, 1, 0]),
            element("AXButton", "Delete", path: [0, 1, 0, 0]),
            element("AXStaticText", "Invoice 20418", path: [0, 1, 0, 1], source: .value),
        ][...]
        XCTAssertEqual(TreeReader.namingText(in: descendants, below: 2), "Invoice 20418")
    }

    func testNamingTextIsOnlyLookedForNearby() {
        let deep: ArraySlice<Element> = [
            element("AXStaticText", "far away", path: [0, 1, 2, 3, 4, 5, 6], source: .value),
        ][...]
        XCTAssertNil(TreeReader.namingText(in: deep, below: 2))
    }
}

final class TextTests: XCTestCase {

    func testHeadingsAreNotPrintedTwice() {
        // Chrome reports a heading and the static text inside it, both
        // carrying the same words.
        let lines = TextExtraction.lines(from: [
            element("AXHeading", "Fixture", source: .value),
            element("AXStaticText", "Fixture", source: .value),
            element("AXStaticText", "Body text", source: .value),
        ])
        XCTAssertEqual(lines, ["Fixture", "Body text"])
    }

    func testFieldsContributeTheirContentsAndPasswordsNothing() {
        let lines = TextExtraction.lines(from: [
            element("AXTextField", "Name", value: "Ada", source: .placeholder),
            element("AXTextField", nil, subrole: "AXSecureTextField", value: "hunter2", secure: true),
            element("AXButton", "Save"),
        ])
        XCTAssertEqual(lines, ["Ada"])
    }
}
