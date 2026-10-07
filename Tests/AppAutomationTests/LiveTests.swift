//
//  LiveTests.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Driving a real app, and asking the app what happened.
//
//  Opt-in: `APPAUTOMATION_LIVE=1 swift test --filter LiveTests`. It needs a
//  logged-in, UNLOCKED GUI session and an Accessibility grant for whatever
//  runs the tests, and it opens a window — none of which a CI runner has.
//  The fixture activates itself, so it takes focus while the suite runs.
//
//  Every assertion that matters is made against the FIXTURE's own report of
//  its state, never against Accessibility's answer. Accessibility's answers
//  are what is under test, and one of them — a web button returning success
//  for a press it ignored — is the reason this suite exists.
//

import AppKit
import XCTest
@testable import AppAutomation

final class LiveTests: XCTestCase {

    private var process: Process!
    private var output: Pipe!
    private var session: AppSession!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["APPAUTOMATION_LIVE"] == "1",
                          "set APPAUTOMATION_LIVE=1")
        try XCTSkipUnless(Automation.isTrusted, "grant Accessibility to whatever runs the tests")
        // Locked, no window is visible to Accessibility and nothing can come
        // forward — every test here would fail for a reason that is not a bug.
        try XCTSkipIf(Automation.isScreenLocked, "the screen is locked")

        // The fixture is built beside the test bundle, as a dependency.
        let fixture = Bundle(for: Self.self).bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("AutomationFixture")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: fixture.path),
                          "no fixture at \(fixture.path)")

        process = Process()
        process.executableURL = fixture
        output = Pipe()
        process.standardOutput = output
        try process.run()

        // Registered with the workspace and its window up: the first state
        // line is printed once the window exists.
        XCTAssertNotNil(waitForState { _ in true }, "the fixture never reported")
        let pid = process.processIdentifier
        let app = try XCTUnwrap(NSRunningApplication(processIdentifier: pid))
        session = try AppSession(RunningApp(app))
    }

    override func tearDown() {
        process?.terminate()
        process?.waitUntilExit()
    }

    // MARK: - Reading

    func testTheSnapshotHasTheFixturesControls() throws {
        let snapshot = try session.snapshot()
        let labels = Set(snapshot.elements.compactMap(\.label))
        for expected in ["Increment", "Open Alert", "Name", "Agree", "Volume", "Locked"] {
            XCTAssertTrue(labels.contains(expected), "missing \(expected)")
        }
        XCTAssertFalse(snapshot.isTruncated)
    }

    func testThePasswordIsNeverRead() throws {
        let secure = try XCTUnwrap(session.snapshot().elements.first(where: \.isSecure))
        XCTAssertNil(secure.value)
        XCTAssertFalse(try session.text().contains("hunter2"))
    }

    func testMenusReadAsPaths() throws {
        // The first menu in an app's main menu IS the application menu, and
        // it carries the app's name whatever the code titled it.
        let items = try session.menuItems()
        let hello = try XCTUnwrap(items.first { $0.path == ["AutomationFixture", "Say Hello"] })
        XCTAssertEqual(hello.shortcut, "⌘H")
        XCTAssertEqual(items.first { $0.path == ["AutomationFixture", "Never"] }?.isEnabled, false)
    }

    // MARK: - Acting

    func testPress() throws {
        let button = try session.resolve(ElementQuery("Increment", role: "button"))
        let result = try session.press(button.ref)
        XCTAssertEqual(result.method, .press)
        XCTAssertNotNil(waitForState { $0["presses"] as? Int == 1 }, "the fixture never saw the press")
    }

    func testSetAndTypeArriveInTheField() throws {
        let field = try session.resolve(ElementQuery("Name", role: "text-field"))
        XCTAssertEqual(try session.setValue(field.ref, to: "Ada").verified, true)
        XCTAssertNotNil(waitForState { $0["name"] as? String == "Ada" })

        // Typed, not set: the app sees each keystroke, posted to its pid.
        XCTAssertEqual(try session.type(" Lovelace 😀", into: field.ref).verified, true)
        XCTAssertNotNil(waitForState { $0["name"] as? String == "Ada Lovelace 😀" })
    }

    func testCheckboxSliderAndPopup() throws {
        let agree = try session.resolve(ElementQuery("Agree", role: "checkbox"))
        try session.setValue(agree.ref, to: "on")
        XCTAssertNotNil(waitForState { $0["agree"] as? Bool == true })
        XCTAssertEqual(try session.press(agree.ref).verified, true)
        XCTAssertNotNil(waitForState { $0["agree"] as? Bool == false })

        let volume = try session.resolve(ElementQuery("Volume", role: "slider"))
        try session.setValue(volume.ref, to: "0.75")
        XCTAssertNotNil(waitForState { ($0["volume"] as? Double).map { abs($0 - 0.75) < 0.001 } ?? false })

        let size = try session.resolve(ElementQuery(role: "popup"))
        XCTAssertEqual(try session.pick("Large...", in: size.ref).verified, true)
        XCTAssertNotNil(waitForState { $0["size"] as? String == "Large…" })
    }

    func testMenuItemsAreChosenWithTheMenuClosed() throws {
        try session.chooseMenu(["AutomationFixture", "Say Hello"])
        XCTAssertNotNil(waitForState { $0["log"] as? String == "hello" })

        XCTAssertThrowsError(try session.chooseMenu(["AutomationFixture", "Never"])) {
            XCTAssertEqual($0 as? AutomationError, .menuItemDisabled("AutomationFixture > Never"))
        }
        XCTAssertThrowsError(try session.chooseMenu(["AutomationFixture", "Nothing"])) {
            XCTAssertEqual($0 as? AutomationError, .noSuchMenuItem("AutomationFixture > Nothing"))
        }
    }

    func testAPressThatOpensADialogIsAPressNotAFailure() throws {
        // Measured: kAXErrorCannotComplete after the timeout, with the alert
        // on screen. Reported as a note, not thrown.
        let short = try AppSession(session.app, timeout: 1)
        let button = try short.resolve(ElementQuery("Open Alert", role: "button"))
        let result = try short.press(button.ref)
        XCTAssertNotNil(result.note)
        XCTAssertNotNil(waitForState { $0["log"] as? String == "alert" })

        let ok = try short.resolve(ElementQuery("OK", role: "button"), in: .allWindows)
        try short.press(ok.ref)
        XCTAssertNotNil(waitForState { $0["log"] as? String == "alert closed" })
    }

    // MARK: - Refusing

    func testPasswordFieldsAreRefused() throws {
        let secure = try XCTUnwrap(session.snapshot().elements.first(where: \.isSecure))
        XCTAssertThrowsError(try session.setValue(secure.ref, to: "x")) {
            XCTAssertEqual($0 as? AutomationError, .secureField(secure.described))
        }
        XCTAssertThrowsError(try session.type("x", into: secure.ref)) {
            XCTAssertEqual($0 as? AutomationError, .secureField(secure.described))
        }
    }

    func testDisabledButtonsAreRefused() throws {
        let locked = try session.resolve(ElementQuery("Locked", role: "button"))
        XCTAssertThrowsError(try session.press(locked.ref)) {
            XCTAssertEqual($0 as? AutomationError, .disabled(locked.described))
        }
    }

    func testAStaleRefIsRefusedRatherThanPressingSomethingElse() throws {
        let button = try session.resolve(ElementQuery("Increment", role: "button"))
        let forged = ElementRef(path: button.ref.path, fingerprint: "0000")
        XCTAssertThrowsError(try session.press(forged)) {
            XCTAssertEqual($0 as? AutomationError, .stale(forged))
        }
        // And nothing was pressed.
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(lastState?["presses"] as? Int, 0)
    }

    func testValuesThatCannotFitAreRefusedBeforeAnythingIsSent() throws {
        let volume = try session.resolve(ElementQuery("Volume", role: "slider"))
        XCTAssertThrowsError(try session.setValue(volume.ref, to: "loud"))
    }

    // MARK: - The fixture's side

    private var buffer = Data()
    private var lastState: [String: Any]?

    /// Reads the fixture's state lines until one satisfies `condition`.
    @discardableResult
    private func waitForState(timeout: TimeInterval = 3, _ condition: ([String: Any]) -> Bool) -> [String: Any]? {
        let handle = output.fileHandleForReading
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // Split on the byte, not the Character: a CRLF would hide a line.
            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                if let state = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                    lastState = state
                    if condition(state) { return state }
                }
            }
            let chunk = handle.availableData
            if chunk.isEmpty { Thread.sleep(forTimeInterval: 0.02) } else { buffer.append(chunk) }
        }
        return nil
    }
}
