//
//  InputTests.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Turning what a caller wrote into something an app accepts: keystrokes,
//  values, menu paths, app names. None of these touch an app.
//

import XCTest
@testable import AppAutomation

final class KeystrokeTests: XCTestCase {

    func testPlainTextIsOneStroke() {
        XCTAssertEqual(Keystrokes.strokes(for: "Ada"), [.text(Array("Ada".utf16))])
    }

    func testNewlinesAndTabsAreKeysNotCharacters() {
        // A field decides what Return means; a raw "\n" bypasses that.
        XCTAssertEqual(
            Keystrokes.strokes(for: "a\nb\tc"),
            [.text([97]), .key(Keystrokes.Key.return), .text([98]), .key(Keystrokes.Key.tab), .text([99])]
        )
    }

    func testCRLFIsOneReturn() {
        // "\r\n" is one Swift Character; split by scalar, it must still be a
        // single Return rather than two, or none.
        XCTAssertEqual(Keystrokes.strokes(for: "a\r\nb"), [.text([97]), .key(Keystrokes.Key.return), .text([98])])
    }

    func testLongTextIsChunked() {
        let strokes = Keystrokes.strokes(for: String(repeating: "x", count: 250))
        XCTAssertEqual(strokes.count, 3)
        guard case .text(let first) = strokes[0] else { return XCTFail("expected text") }
        XCTAssertEqual(first.count, Keystrokes.chunkSize)
    }

    func testAChunkNeverSplitsAnEmoji() {
        // A surrogate pair split across events arrives as two replacement
        // characters.
        let text = String(repeating: "x", count: 99) + "😀" + "y"
        let strokes = Keystrokes.strokes(for: text)
        for stroke in strokes {
            guard case .text(let units) = stroke, let last = units.last else { continue }
            XCTAssertFalse(UTF16.isLeadSurrogate(last), "a chunk ended on half an emoji")
        }
        let rejoined = strokes.flatMap { stroke -> [UInt16] in
            if case .text(let units) = stroke { return units }
            return []
        }
        XCTAssertEqual(String(decoding: rejoined, as: UTF16.self), text)
    }
}

final class ValueTests: XCTestCase {

    func testNumbersPrintWithoutATrailingZero() {
        XCTAssertEqual(ValueCoercion.format(1), "1")
        XCTAssertEqual(ValueCoercion.format(0.25), "0.25")
    }

    func testToggleWords() {
        for word in ["on", "1", "TRUE", "yes", "checked"] { XCTAssertEqual(ValueCoercion.flag(word), true, word) }
        for word in ["off", "0", "false", "no"] { XCTAssertEqual(ValueCoercion.flag(word), false, word) }
        XCTAssertNil(ValueCoercion.flag("maybe"))
    }

    func testTheValueTakesTheTypeTheElementAlreadyHolds() {
        // Setting the string "1" on a checkbox fails; it needs the number.
        XCTAssertEqual(ValueCoercion.value(from: "on", current: NSNumber(value: 0), isToggle: true) as? NSNumber, 1)
        XCTAssertEqual(ValueCoercion.value(from: "0.75", current: NSNumber(value: 0.25), isToggle: false) as? NSNumber, 0.75)
        XCTAssertEqual(ValueCoercion.value(from: "Ada", current: "" as NSString, isToggle: false) as? String, "Ada")
        XCTAssertNil(ValueCoercion.value(from: "loud", current: NSNumber(value: 0.25), isToggle: false))
        XCTAssertNil(ValueCoercion.value(from: "maybe", current: NSNumber(value: 0), isToggle: true))
    }

    func testReadBackComparesLikeForLike() {
        XCTAssertTrue(ValueCoercion.same("0.5", "0.5000000001", isToggle: false))
        XCTAssertTrue(ValueCoercion.same("on", "1", isToggle: true))
        XCTAssertFalse(ValueCoercion.same("Ada", "ada", isToggle: false))
        XCTAssertFalse(ValueCoercion.same("Ada", nil, isToggle: false))
    }
}

final class MenuTests: XCTestCase {

    func testPathsInEveryCommonSpelling() {
        XCTAssertEqual(MenuPath.parse("File > New Folder"), ["File", "New Folder"])
        XCTAssertEqual(MenuPath.parse("View ▸ Sort By ▸ Name"), ["View", "Sort By", "Name"])
        XCTAssertEqual(MenuPath.parse(" > File > "), ["File"])
    }

    func testTitlesIgnoreCaseAndEllipses() {
        // Menus write "Save As…" with the single character; people type
        // three dots, or none.
        XCTAssertTrue(MenuPath.matches("save as", title: "Save As…"))
        XCTAssertTrue(MenuPath.matches("Save As...", title: "Save As…"))
        XCTAssertTrue(MenuPath.matches("Save As…", title: "Save As..."))
        XCTAssertFalse(MenuPath.matches("Save", title: "Save As…"))
    }

    func testShortcutsHaveCommandUnlessTheMaskSaysOtherwise() {
        // Bit 3 means NO command; a mask of 0 is ⌘ alone.
        XCTAssertEqual(MenuShortcut.format(character: "N", modifiers: 0), "⌘N")
        XCTAssertEqual(MenuShortcut.format(character: "N", modifiers: 1), "⇧⌘N")
        XCTAssertEqual(MenuShortcut.format(character: "N", modifiers: 1 | 2 | 4), "⌃⌥⇧⌘N")
        XCTAssertEqual(MenuShortcut.format(character: "F", modifiers: 8), "F")
        XCTAssertNil(MenuShortcut.format(character: nil, modifiers: 0))
    }
}

final class AppMatchingTests: XCTestCase {

    let apps = [
        RunningApp(pid: 10, name: "Notes", bundleID: "com.apple.Notes", isActive: false, isHidden: false),
        RunningApp(pid: 11, name: "Sticky Notes", bundleID: "com.example.sticky", isActive: false, isHidden: false),
        RunningApp(pid: 12, name: "Google Chrome", bundleID: "com.google.Chrome", isActive: true, isHidden: false),
        RunningApp(pid: 13, name: "Google Drive", bundleID: "com.google.drivefs", isActive: false, isHidden: false),
    ]

    func testAnExactNameIsNotShadowedByALongerOne() {
        XCTAssertEqual(AppMatching.select("notes", from: apps).map(\.pid), [10])
    }

    func testPidAndBundleIdentifier() {
        XCTAssertEqual(AppMatching.select("12", from: apps).map(\.pid), [12])
        XCTAssertEqual(AppMatching.select("com.google.chrome", from: apps).map(\.pid), [12])
    }

    func testPartialNames() {
        XCTAssertEqual(AppMatching.select("chrome", from: apps).map(\.pid), [12])
        XCTAssertEqual(AppMatching.select("Google", from: apps).map(\.pid), [12, 13])
        XCTAssertTrue(AppMatching.select("Safari", from: apps).isEmpty)
    }
}

final class SettleTests: XCTestCase {

    func testReturnsAsSoonAsTheConditionHolds() {
        var calls = 0
        var slept = 0.0
        let held = Settle.until(timeout: 1, interval: 0.1, sleep: { slept += $0 }) {
            calls += 1
            return calls == 3
        }
        XCTAssertTrue(held)
        XCTAssertEqual(slept, 0.2, accuracy: 1e-9)
    }

    func testGivesUpAtTheTimeout() {
        var slept = 0.0
        XCTAssertFalse(Settle.until(timeout: 0.5, interval: 0.1, sleep: { slept += $0 }) { false })
        XCTAssertEqual(slept, 0.5, accuracy: 1e-9)
    }
}

final class SessionStateTests: XCTestCase {

    func testTheLockFlag() {
        // Measured locked: present, as 1.
        XCTAssertTrue(SessionState.isLocked(["CGSSessionScreenIsLocked": NSNumber(value: 1)]))
        XCTAssertFalse(SessionState.isLocked(["CGSSessionScreenIsLocked": NSNumber(value: 0)]))
        XCTAssertFalse(SessionState.isLocked(["kCGSessionOnConsoleKey": NSNumber(value: 1)]))
    }
}
