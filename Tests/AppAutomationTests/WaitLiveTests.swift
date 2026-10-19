//
//  WaitLiveTests.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Waiting on a real app that changes itself on a schedule.
//
//  Opt-in, like LiveTests: `APPAUTOMATION_LIVE=1 swift test --filter
//  WaitLiveTests`. Unlike LiveTests it takes NOBODY's focus and touches
//  nothing: the fixture runs in its timeline mode — never activated, its
//  window ordered to the back — and every call here only reads. It still
//  needs an unlocked GUI session and an Accessibility grant.
//
//  The schedule is the fixture's (see its main.swift): "Late" appears
//  disabled at 0.8 s and is enabled at 1.4 s, Status goes from "working" to
//  "done" at 1.7 s, "Late" is removed at 2.2 s, and the window closes at
//  2.6 s. The fixture reports each step itself, so
//  the timings asserted are bounds around those, never exact.
//

import AppKit
import XCTest
@testable import AppAutomation

final class WaitLiveTests: XCTestCase {

    private var process: Process!
    private var session: AppSession!
    private var launched = Date()

    /// The one test that starts waiting the moment the fixture exists,
    /// before it can answer Accessibility, rather than once its window is up.
    private var startsAtLaunch: Bool { name.contains("RightAfterLaunch") }

    /// Whether the fixture refused a notification registration at the moment
    /// the launch test began — the race that test exists to cover.
    private var refusedAtStart = false

    private let late = ElementQuery("Late", role: "button")
    private func late(_ requirement: WaitRequirement) -> WaitCondition {
        WaitCondition(.element(late, in: .allWindows), requirement)
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["APPAUTOMATION_LIVE"] == "1",
                          "set APPAUTOMATION_LIVE=1")
        try XCTSkipUnless(Automation.isTrusted, "grant Accessibility to whatever runs the tests")
        try XCTSkipIf(Automation.isScreenLocked, "the screen is locked")

        let fixture = Bundle(for: Self.self).bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("AutomationFixture")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: fixture.path),
                          "no fixture at \(fixture.path)")

        process = Process()
        process.executableURL = fixture
        process.environment = ProcessInfo.processInfo.environment.merging(["AUTOMATION_FIXTURE_TIMELINE": "1"]) { _, new in new }
        process.standardOutput = FileHandle.nullDevice
        launched = Date()
        try process.run()
        let pid = process.processIdentifier

        if startsAtLaunch {
            // At once, by pid: not after the workspace lists the app, which
            // can take long enough for it to be ready, and then the test
            // proves nothing.
            refusedAtStart = ChangeObserver(pid: pid, element: AXUIElementCreateApplication(pid)) == nil
            session = try AppSession(RunningApp(pid: pid, name: "AutomationFixture", bundleID: nil,
                                                isActive: false, isHidden: false))
            return
        }

        // Registered with the workspace, then its window up — waited for with
        // the library itself, which is part of what is under test.
        var running: NSRunningApplication?
        for _ in 0..<100 where running == nil {
            running = NSRunningApplication(processIdentifier: pid)
            if running == nil { Thread.sleep(forTimeInterval: 0.02) }
        }
        session = try AppSession(RunningApp(try XCTUnwrap(running)))
        let up = try session.wait(until: [WaitCondition(.window("Automation Fixture"))],
                                  options: WaitOptions(timeout: 5, stable: 1))
        XCTAssertEqual(up.outcome, .satisfied, "the fixture's window never appeared")
    }

    override func tearDown() {
        process?.terminate()
        process?.waitUntilExit()
    }

    func testAWaitStartedRightAfterLaunchStillHearsTheApp() throws {
        // Measured: the app refuses notification registrations for its first
        // ~150 ms. This wait starts inside that window — checked, not assumed
        // — and polls only every 4 s. Status changes ~2 s in (1.7 s after the
        // fixture finishes launching). A wait that kept asking hears it then;
        // one that asked once, or only between polls, cannot look before 4 s.
        XCTAssertTrue(refusedAtStart, "the fixture was listening already — the race did not happen")
        let status = WaitCondition(.element(ElementQuery("Status", role: "text-field"), in: .allWindows),
                                   .valueEquals("done"))
        let report = try session.wait(until: [status], options: WaitOptions(timeout: 6, interval: 4, stable: 1))
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertTrue(report.listened)
        XCTAssertGreaterThanOrEqual(report.woken, 1)
        XCTAssertLessThan(report.elapsed, 3.5, "woken by the poll, not the app")
    }

    func testTheAppSayingSoWakesTheWaitBeforeThePoll() throws {
        // Status changes at 1.7 s and AppKit announces it (AXValueChanged) —
        // ~1.4 s into this wait, which starts once the window is up. Polling
        // every 3 s alone would not look again until 3 s.
        let status = WaitCondition(.element(ElementQuery("Status", role: "text-field"), in: .allWindows),
                                   .valueEquals("done"))
        let report = try session.wait(until: [status], options: WaitOptions(timeout: 5, interval: 3, stable: 1))
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertTrue(report.listened)
        XCTAssertGreaterThanOrEqual(report.woken, 1)
        XCTAssertLessThan(report.elapsed, 2.5, "woken by the poll, not the app")
    }

    func testAnUnannouncedAppearanceIsCaughtByPolling() throws {
        // Measured: AppKit sends nothing when a button is added to a window in
        // the background — no AXCreated, no layout change. Polling finds it,
        // at 0.8 s and confirmed at 1.0 s, before it is enabled at 1.4 s.
        let report = try session.wait(until: [late(.exists)], options: WaitOptions(timeout: 5))
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertEqual(report.entries[0].last?.isEnabled, false)
        XCTAssertEqual(report.entries[0].streak, 2)
    }

    func testPollingAloneStillGetsThere() throws {
        let report = try session.wait(until: [late(.exists)], options: WaitOptions(timeout: 5, listens: false))
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertFalse(report.listened)
        XCTAssertEqual(report.woken, 0)
    }

    func testEnabledAndAValueTogether() throws {
        let status = WaitCondition(.element(ElementQuery("Status", role: "text-field"), in: .allWindows),
                                   .valueEquals("done"))
        let report = try session.wait(until: [late(.enabled), status], options: WaitOptions(timeout: 5))
        XCTAssertEqual(report.outcome, .satisfied)
        // Both at once: enabled from 1.4 s was not enough while Status still
        // said "working", until 1.7 s.
        XCTAssertTrue(report.entries.allSatisfy(\.met))
        XCTAssertEqual(report.entries[1].last?.value, "done")
        XCTAssertEqual(report.entries[0].last?.isEnabled, true)
        XCTAssertLessThan(report.entries[0].metAfter ?? 99, report.entries[1].metAfter ?? 0)
    }

    func testItWaitsForTheButtonToGo() throws {
        let shown = try session.wait(until: [late(.exists)], options: WaitOptions(timeout: 5))
        XCTAssertEqual(shown.outcome, .satisfied)
        let gone = try session.wait(until: [late(.gone)], options: WaitOptions(timeout: 5))
        XCTAssertEqual(gone.outcome, .satisfied)
        XCTAssertEqual(gone.entries[0].last?.state, .absent)
        // Gone from a window that is still there — removed at 2.2 s — not
        // gone because the whole window closed at 2.6 s.
        XCTAssertTrue(gone.entries[0].last?.reason?.hasPrefix("nothing matches") ?? false,
                      gone.entries[0].last?.reason ?? "no reason")
    }

    func testTheLastWindowClosingIsGoneNotUnreadable() throws {
        // With no window left, AppKit's off-screen scaffolding is all the
        // window server lists for the app. Counted as windows, it read as
        // "on another Space" — unreadable — and this never succeeded.
        let gone = WaitCondition(.window("Automation Fixture"), .gone)
        let report = try session.wait(until: [gone], options: WaitOptions(timeout: 5))
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertEqual(report.entries[0].last?.state, .absent)

        // And still gone once the close has finished. Measured: for ~0.3 s
        // after the close the window server lists the window ON screen,
        // animating; after that it lists it off-screen, ordered out. A test
        // that only looked during the animation passed while every later
        // reading said "on another Space".
        let settled = launched.addingTimeInterval(3.8).timeIntervalSinceNow
        if settled > 0 { Thread.sleep(forTimeInterval: settled) }
        let later = try session.wait(until: [gone], options: WaitOptions(timeout: 2))
        XCTAssertEqual(later.outcome, .satisfied)
        XCTAssertEqual(later.entries[0].last?.state, .absent, later.entries[0].last?.reason ?? "")
    }

    func testAnAppThatQuitsStopsTheWaitAtOnce() throws {
        // Nothing will ever hold for an app that is gone; the wait says so
        // as soon as it notices, rather than reading a dead process until
        // the timeout and calling that "not found".
        let process = self.process!
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { process.terminate() }
        let report = try session.wait(until: [WaitCondition(.window("No Such Window 7f3c"))],
                                      options: WaitOptions(timeout: 5))
        XCTAssertEqual(report.outcome, .stopped(.noSuchApp(session.app.name)))
        XCTAssertLessThan(report.elapsed, 2)
    }

    func testAWindowThatNeverComesTimesOutWithWhatWasSeen() throws {
        let report = try session.wait(until: [WaitCondition(.window("No Such Window 7f3c"))],
                                      options: WaitOptions(timeout: 0.6))
        XCTAssertEqual(report.outcome, .timedOut)
        XCTAssertEqual(report.entries[0].last?.state, .absent)
        XCTAssertGreaterThanOrEqual(report.elapsed, 0.6)
        XCTAssertLessThan(report.elapsed, 1.2)
    }

    func testAFlickerIsNotConfirmed() throws {
        // "Late" is enabled only from 1.4 s to 2.2 s; asked to see it enabled
        // across readings spanning more than that, the wait must not succeed.
        let report = try session.wait(until: [late(.enabled)],
                                      options: WaitOptions(timeout: 4, interval: 0.5, stable: 3))
        XCTAssertEqual(report.outcome, .timedOut)
        XCTAssertEqual(report.entries[0].last?.state, .absent)
    }
}
