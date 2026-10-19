//
//  WaitTests.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Waiting, against a fake app on a fake clock. The app is a timeline of
//  trees — a button that appears late, flickers, changes value, goes — and
//  the clock only moves when the wait pauses, so every timing below is exact
//  and none of it costs wall-clock.
//

import XCTest
@testable import AppAutomation

/// An app whose interface changes on a schedule, and the clock it runs on.
private final class FakeApp {

    /// From each time on, the tree is these elements — until the next entry.
    var timeline: [(at: TimeInterval, elements: [Element])]

    /// When the app sends a notification. By default, at every change.
    var notifications: [TimeInterval]

    /// Throw this from the first reading at or after a time.
    var failure: (at: TimeInterval, error: AutomationError)?

    private(set) var time: TimeInterval = 0
    private(set) var readTimes: [TimeInterval] = []
    private(set) var subjectsRead: [[WaitSubject]] = []

    init(_ timeline: [(at: TimeInterval, elements: [Element])], notifies: Bool = false,
         notifications extra: [TimeInterval] = []) {
        self.timeline = timeline
        self.notifications = ((notifies ? timeline.map(\.at).filter { $0 > 0 } : []) + extra).sorted()
    }

    var tree: [Element] { timeline.last(where: { $0.at <= time + 1e-9 })?.elements ?? [] }

    var clock: WaitClock {
        WaitClock(now: { self.time }, pause: { seconds in
            let until = self.time + seconds
            if let index = self.notifications.firstIndex(where: { $0 > self.time && $0 <= until }) {
                self.time = self.notifications.remove(at: index)
                return true
            }
            self.time = until
            return false
        })
    }

    func observe(_ subject: WaitSubject) throws -> WaitObservation {
        if let failure, time >= failure.at { throw failure.error }
        // The fake clock only moves when the wait pauses, so a loop that
        // stops pausing would read forever. Fail it instead of hanging.
        if readTimes.count > 10_000 { throw AutomationError.failed("runaway: read without pausing", code: 0) }
        switch subject {
        case .element(let query, _):
            return WaitRules.observe(query, in: tree)
        case .ref(let ref):
            guard let found = tree.first(where: { $0.ref.path == ref.path }) else { return .absent("gone") }
            return found.ref.fingerprint == ref.fingerprint ? .present(found) : .absent("changed")
        case .window(let title):
            let windows = tree.filter { $0.role == "AXWindow" && ($0.label?.contains(title) ?? false) }
            return windows.first.map(WaitObservation.present) ?? .absent("no window")
        }
    }

    func wait(_ conditions: [WaitCondition], _ options: WaitOptions = WaitOptions(timeout: 2)) -> WaitReport {
        let listens = !notifications.isEmpty
        return WaitLoop.run(conditions, options: options, listening: { listens }, clock: clock) { subjects in
            self.readTimes.append(self.time)
            self.subjectsRead.append(subjects)
            return try subjects.map(self.observe)
        }
    }
}

private let save = ElementQuery("Save", role: "button")
private func on(_ query: ElementQuery, _ requirement: WaitRequirement = .exists) -> WaitCondition {
    WaitCondition(.element(query, in: .focusedWindow), requirement)
}
private let saveButton = element("AXButton", "Save", path: [1, 4])

final class WaitLoopTests: XCTestCase {

    func testSomethingAlreadyThereTakesTwoAgreeingReadings() {
        let app = FakeApp([(0, [saveButton])])
        let report = app.wait([on(save)])
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertEqual(report.readings, 2)
        XCTAssertEqual(report.elapsed, 0.2, accuracy: 1e-9)
        XCTAssertEqual(report.entries[0].metAfter ?? -1, 0.2, accuracy: 1e-9)
    }

    func testOneReadingIsEnoughWhenAskedForOne() {
        let app = FakeApp([(0, [saveButton])])
        let report = app.wait([on(save)], WaitOptions(timeout: 2, stable: 1))
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertEqual(report.readings, 1)
    }

    func testALateAppearanceIsSeenOnThePollingSchedule() {
        let app = FakeApp([(0, []), (1.0, [saveButton])])
        let report = app.wait([on(save)])
        XCTAssertEqual(report.outcome, .satisfied)
        // First seen at the 1.0 poll, confirmed at 1.2.
        XCTAssertEqual(report.entries[0].metAfter ?? -1, 1.2, accuracy: 1e-6)
        XCTAssertEqual(report.woken, 0)
        XCTAssertEqual(report.entries[0].last?.ref, saveButton.ref)
    }

    func testAFlickerIsNotAnAnswer() {
        // On screen from 0.35 to 0.5: one poll (0.4) sees it, the next does not.
        let app = FakeApp([(0, []), (0.35, [saveButton]), (0.5, [])])
        let report = app.wait([on(save)], WaitOptions(timeout: 1))
        XCTAssertEqual(report.outcome, .timedOut)
        XCTAssertFalse(report.entries[0].met)
        XCTAssertEqual(report.entries[0].last?.state, .absent)
    }

    func testAFlickerTheAppKeepsAnnouncingCannotConfirmItself() {
        // The app chatters while the button is up: readings come at 0.375 and
        // 0.425, both see it — and they are too close together to count twice.
        let app = FakeApp([(0, []), (0.35, [saveButton]), (0.5, [])],
                          notifies: true, notifications: [0.4, 0.41, 0.42])
        let report = app.wait([on(save)], WaitOptions(timeout: 1))
        XCTAssertEqual(report.outcome, .timedOut)
        XCTAssertGreaterThanOrEqual(app.readTimes.filter { $0 >= 0.35 && $0 < 0.5 }.count, 2,
                                    "the flicker was read more than once")
    }

    func testANotificationBringsTheReadingForward() {
        // Polling every second would first see it at 1.0.
        let app = FakeApp([(0, []), (0.3, [saveButton])], notifies: true)
        let report = app.wait([on(save)], WaitOptions(timeout: 3, interval: 1, stable: 1))
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertEqual(report.elapsed, 0.3 + WaitLoop.coalesce, accuracy: 1e-9)
        XCTAssertEqual(report.woken, 1)
        XCTAssertTrue(report.listened)
    }

    func testReadingsAreNeverCloserThanTheMinimumGap() {
        let chatter = stride(from: 0.01, to: 1.0, by: 0.01).map { $0 }
        let app = FakeApp([(0, [])], notifications: chatter)
        _ = app.wait([on(save)], WaitOptions(timeout: 1))
        let gaps = zip(app.readTimes.dropFirst(), app.readTimes).map { $0 - $1 }
        XCTAssertGreaterThanOrEqual(gaps.min() ?? 0, WaitLoop.minimumGap - 1e-9)
    }

    func testAValueChangeIsWaitedFor() {
        let working = element("AXTextField", "Status", value: "working", path: [1, 2])
        let done = element("AXTextField", "Status", value: "done", path: [1, 2])
        let app = FakeApp([(0, [working]), (0.5, [done])])
        let report = app.wait([on(ElementQuery("Status"), .valueEquals("done"))])
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertEqual(report.entries[0].last?.value, "done")
        XCTAssertEqual(report.entries[0].metAfter ?? -1, 0.8, accuracy: 1e-6)
    }

    func testAValueThatKeepsChangingNeverSettles() {
        // Contains "4" every time; the same value twice, never.
        let app = FakeApp((0..<12).map { step in
            (TimeInterval(step) * 0.2, [element("AXStaticText", "Counter", value: "\(step)4", path: [1, 1])])
        })
        let report = app.wait([on(ElementQuery("Counter"), .valueContains("4"))], WaitOptions(timeout: 2))
        XCTAssertEqual(report.outcome, .timedOut)
        XCTAssertEqual(report.entries[0].streak, 1)
    }

    func testADisappearance() {
        let app = FakeApp([(0, [saveButton]), (0.7, [])])
        let report = app.wait([on(save, .gone)])
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertEqual(report.entries[0].metAfter ?? -1, 1.0, accuracy: 1e-6)
        XCTAssertEqual(report.entries[0].last?.state, .absent)
    }

    func testARefIsGoneWhenSomethingElseTakesItsPlace() {
        let replaced = element("AXButton", "Delete", path: [1, 4])
        let app = FakeApp([(0, [saveButton]), (0.3, [replaced])])
        let report = app.wait([WaitCondition(.ref(saveButton.ref), .gone)])
        XCTAssertEqual(report.outcome, .satisfied)
    }

    func testEveryConditionMustHoldAtTheSameReading() {
        let disabled = element("AXButton", "Save", value: "draft", path: [1, 4], enabled: false)
        let enabled = element("AXButton", "Save", value: "draft", path: [1, 4])
        let final = element("AXButton", "Save", value: "final", path: [1, 4])
        let app = FakeApp([(0, [disabled]), (0.3, [enabled]), (0.9, [final])])
        let report = app.wait([on(save, .enabled), on(save, .valueEquals("final"))])
        XCTAssertEqual(report.outcome, .satisfied)
        // Enabled from 0.4, but its value changed at 0.9 — a different
        // reading, so it was confirmed again alongside the value.
        XCTAssertEqual(report.entries[1].metAfter ?? -1, 1.2, accuracy: 1e-6)
        XCTAssertEqual(report.elapsed, 1.2, accuracy: 1e-6)
        // One subject, read once per reading.
        XCTAssertTrue(app.subjectsRead.allSatisfy { $0.count == 1 })
    }

    func testTwoMatchesAreNeverExists() {
        let twins = [saveButton, element("AXButton", "Save", path: [1, 9])]
        let app = FakeApp([(0, twins)])
        let report = app.wait([on(save)], WaitOptions(timeout: 0.5))
        XCTAssertEqual(report.outcome, .timedOut)
        XCTAssertEqual(report.entries[0].last?.state, .ambiguous)
        XCTAssertEqual(report.entries[0].last?.candidates, twins.map(\.ref))
    }

    func testThePasswordFieldsValueIsRefused() {
        let secret = element("AXTextField", "Password", subrole: "AXSecureTextField", path: [1, 3], secure: true)
        let app = FakeApp([(0, [secret])])
        let report = app.wait([on(ElementQuery("Password"), .valueEquals("hunter2"))])
        XCTAssertEqual(report.outcome, .stopped(.secureField(secret.described)))
        XCTAssertEqual(report.readings, 1)
    }

    func testAnErrorStopsTheWaitAndKeepsWhatWasSeen() {
        let app = FakeApp([(0, [])])
        app.failure = (0.4, .screenLocked)
        let report = app.wait([on(save)])
        XCTAssertEqual(report.outcome, .stopped(.screenLocked))
        XCTAssertEqual(report.entries[0].readings, 2)
        XCTAssertEqual(report.entries[0].last?.state, .absent)
    }

    func testTheDeadlineIsAlwaysRead() {
        // Polls at 0, 0.3, 0.6, 0.9 — then 1.0, the deadline, not 1.2.
        let app = FakeApp([(0, []), (0.95, [saveButton])])
        let report = app.wait([on(save)], WaitOptions(timeout: 1, interval: 0.3, stable: 1))
        XCTAssertEqual(report.outcome, .satisfied)
        XCTAssertEqual(report.elapsed, 1.0, accuracy: 1e-9)
    }

    func testATimeoutReadsNoFurtherThanTheDeadline() {
        let app = FakeApp([(0, [])])
        let report = app.wait([on(save)], WaitOptions(timeout: 1))
        XCTAssertEqual(report.outcome, .timedOut)
        XCTAssertEqual(report.elapsed, 1.0, accuracy: 1e-9)
        XCTAssertEqual(report.readings, 6)
    }
}

final class StabilityTests: XCTestCase {

    let seen = WaitReading(state: .present, ref: ElementRef(path: [1], fingerprint: "abcd"), value: "a")

    func testItCountsAgreeingReadingsOnTime() {
        var run = Stability(required: 3, spacing: 0.18)
        run.record(seen, satisfied: true, at: 0)
        run.record(seen, satisfied: true, at: 0.2)
        XCTAssertFalse(run.isMet)
        run.record(seen, satisfied: true, at: 0.4)
        XCTAssertTrue(run.isMet)
        XCTAssertEqual(run.metAfter, 0.4)
    }

    func testAReadingTooSoonNeitherCountsNorBreaksTheRun() {
        var run = Stability(required: 2, spacing: 0.18)
        run.record(seen, satisfied: true, at: 0)
        run.record(seen, satisfied: true, at: 0.05)
        XCTAssertEqual(run.streak, 1)
        run.record(seen, satisfied: true, at: 0.2)
        XCTAssertEqual(run.streak, 2)
    }

    func testADifferentReadingStartsAgain() {
        var run = Stability(required: 2, spacing: 0.18)
        run.record(seen, satisfied: true, at: 0)
        let other = WaitReading(state: .present, ref: seen.ref, value: "b")
        run.record(other, satisfied: true, at: 0.2)
        XCTAssertEqual(run.streak, 1)
        XCTAssertNil(run.metAfter)
    }

    func testAnUnsatisfyingReadingResetsAMetRun() {
        var run = Stability(required: 1, spacing: 0.18)
        run.record(seen, satisfied: true, at: 0)
        XCTAssertTrue(run.isMet)
        run.record(WaitReading(state: .absent), satisfied: false, at: 0.2)
        XCTAssertFalse(run.isMet)
        XCTAssertNil(run.metAfter)
        XCTAssertEqual(run.readings, 2)
    }

    func testTheReasonIsNotPartOfTheReading() {
        // "No windows" and "nothing matches" are both absent.
        XCTAssertEqual(WaitReading(state: .absent, reason: "no windows"),
                       WaitReading(state: .absent, reason: "nothing matches"))
        XCTAssertNotEqual(WaitReading(state: .absent), WaitReading(state: .unreadable))
    }
}

final class WaitRuleTests: XCTestCase {

    func reading(_ element: Element) -> WaitReading { WaitRules.reading(.present(element)) }

    func testRequirements() {
        let field = reading(element("AXTextField", "Name", value: "Ada Lovelace"))
        XCTAssertTrue(WaitRules.satisfies(.exists, field))
        XCTAssertFalse(WaitRules.satisfies(.gone, field))
        XCTAssertTrue(WaitRules.satisfies(.valueEquals("Ada Lovelace"), field))
        XCTAssertFalse(WaitRules.satisfies(.valueEquals("ada lovelace"), field))
        XCTAssertTrue(WaitRules.satisfies(.valueContains("Love"), field))
        XCTAssertFalse(WaitRules.satisfies(.valueContains("love"), field))
        XCTAssertTrue(WaitRules.satisfies(.enabled, field))
        XCTAssertFalse(WaitRules.satisfies(.disabled, field))
        XCTAssertTrue(WaitRules.satisfies(.disabled, reading(element("AXButton", "Locked", enabled: false))))
    }

    func testOnlyAbsentIsGone() {
        XCTAssertTrue(WaitRules.satisfies(.gone, WaitReading(state: .absent)))
        // Could not look is not "not there", and two is not none.
        XCTAssertFalse(WaitRules.satisfies(.gone, WaitReading(state: .unreadable)))
        XCTAssertFalse(WaitRules.satisfies(.gone, WaitReading(state: .ambiguous)))
        XCTAssertFalse(WaitRules.satisfies(.exists, WaitReading(state: .ambiguous)))
        XCTAssertFalse(WaitRules.satisfies(.disabled, WaitReading(state: .absent)))
    }

    func testSelectedIsAXSelectedOrACheckboxThatIsOn() {
        XCTAssertTrue(WaitRules.satisfies(.selected, reading(element("AXRow", "Inbox", selected: true))))
        XCTAssertFalse(WaitRules.satisfies(.selected, reading(element("AXRow", "Inbox"))))
        XCTAssertTrue(WaitRules.satisfies(.selected, reading(element("AXCheckBox", "Agree", value: "1"))))
        XCTAssertFalse(WaitRules.satisfies(.selected, reading(element("AXCheckBox", "Agree", value: "0"))))
        // A text field holding "1" is not on.
        XCTAssertFalse(WaitRules.satisfies(.selected, reading(element("AXTextField", "Count", value: "1"))))
    }

    func testNothingFoundInACutShortTreeIsUnreadable() {
        let query = ElementQuery("Save")
        XCTAssertEqual(WaitRules.observe(query, in: [], truncated: false), .absent("nothing matches “Save”"))
        guard case .unreadable = WaitRules.observe(query, in: [element("AXGroup")], truncated: true) else {
            return XCTFail("a truncated read said gone")
        }
        XCTAssertEqual(WaitRules.observe(query, in: [saveButton], truncated: true), .present(saveButton))
    }

    func testAnExactLabelStillBeatsAPartialOne() {
        let saveAs = element("AXButton", "Save As…", path: [1, 5])
        XCTAssertEqual(WaitRules.observe(save, in: [saveButton, saveAs]), .present(saveButton))
    }

    func testDescriptions() {
        XCTAssertEqual(on(save, .enabled).described, "button “Save” is enabled")
        XCTAssertEqual(WaitCondition(.window("Untitled")).described, "window “Untitled” exists")
        XCTAssertEqual(WaitCondition(.ref(saveButton.ref), .gone).described, "\(saveButton.ref) is gone")
        XCTAssertEqual(WaitCondition(.element(ElementQuery("Name"), in: .window("Inbox")), .valueEquals("Ada")).described,
                       "“Name” in window “Inbox” has the value “Ada”")
        XCTAssertEqual(on(ElementQuery(identifier: "send")).described, "id “send” exists")
    }
}

final class IdentifierQueryTests: XCTestCase {

    func testAnIdentifierIsMatchedWhole() {
        let send = element("AXButton", "Send", path: [1, 1], identifier: "composeSend")
        let other = element("AXButton", "Send", path: [1, 2], identifier: "replySend")
        XCTAssertEqual(QueryMatching.select(ElementQuery(identifier: "composeSend"), from: [send, other]), [send])
        XCTAssertEqual(QueryMatching.select(ElementQuery("Send", identifier: "replySend"), from: [send, other]), [other])
        XCTAssertTrue(QueryMatching.select(ElementQuery(identifier: "compose"), from: [send, other]).isEmpty)
        XCTAssertTrue(QueryMatching.select(ElementQuery(identifier: "composesend"), from: [send, other]).isEmpty)
    }
}

final class WindowCensusTests: XCTestCase {

    /// A window-server entry, as `CGWindowListCopyWindowInfo` gives it.
    func window(_ number: Int, pid: pid_t = 42, layer: Int = 0, onscreen: Bool = false) -> [String: Any] {
        [kCGWindowNumber as String: number, kCGWindowOwnerPID as String: pid,
         kCGWindowLayer as String: layer, kCGWindowIsOnscreen as String: onscreen]
    }

    func testAWindowOnNoSpaceIsNotElsewhere() {
        // Scaffolding and windows closed but kept alive: off-screen, and in
        // no Space's window list — 91 of 92 measured.
        XCTAssertEqual(WindowCensus.elsewhere([window(1), window(2), window(3)], pid: 42, listed: []), 0)
    }

    func testAListedWindowOffScreenIsElsewhere() {
        XCTAssertEqual(WindowCensus.elsewhere([window(1), window(2)], pid: 42, listed: [2]), 1)
    }

    func testWithoutTheListEveryOffScreenWindowCounts() {
        // The safe direction: "cannot tell", never "gone".
        XCTAssertEqual(WindowCensus.elsewhere([window(1), window(2)], pid: 42, listed: nil), 2)
    }

    func testTheListIsReadOnAndOffTheMainThread() {
        XCTAssertNotNil(WindowCensus.listedWindowNumbers())
        let read = expectation(description: "read off the main thread")
        DispatchQueue.global().async {
            XCTAssertNotNil(WindowCensus.listedWindowNumbers())
            read.fulfill()
        }
        wait(for: [read], timeout: 3)
    }

    func testOnScreenOtherLayersAndOtherAppsAreNotCounted() {
        let info = [window(1, onscreen: true), window(2, layer: 25), window(3, pid: 7)]
        XCTAssertEqual(WindowCensus.elsewhere(info, pid: 42, listed: [1, 2, 3]), 0)
    }
}
