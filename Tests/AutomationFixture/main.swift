//
//  main.swift
//  AutomationFixture
//
//  Created by David Sherlock on 2026.
//
//  A window with known controls, for the live tests to drive.
//
//  The point is GROUND TRUTH. Accessibility's own answers are what is being
//  tested, so they cannot be the evidence: a web button returns success for a
//  press it ignored. This app prints its own state, as one JSON line on
//  stdout, every time anything in it changes — so a test asserts what the app
//  SAW, from the app's side.
//
//  With AUTOMATION_FIXTURE_TIMELINE=1 it is a fixture for WAITING instead:
//  it stays in the background — never activates, window ordered to the back,
//  so a test that only reads takes nobody's focus — and changes itself on a
//  schedule, reporting each step: a "Late" button appears disabled at 0.8 s
//  and is enabled at 1.4 s, the Status field goes from "working" to "done"
//  at 1.7 s, the button is removed at 2.2 s, and the window closes at 2.6 s
//  — kept alive, as many apps keep theirs, but with none left on screen.
//

import AppKit

/// The fixture's window and its controls.
@MainActor
final class Fixture: NSObject, NSApplicationDelegate, NSTextFieldDelegate {

    var window: NSWindow!
    var presses = 0
    let count = NSTextField(labelWithString: "Count: 0")
    let name = NSTextField(string: "")
    let agree = NSButton(checkboxWithTitle: "Agree", target: nil, action: nil)
    let size = NSPopUpButton()
    let volume = NSSlider(value: 0.25, minValue: 0, maxValue: 1, target: nil, action: nil)
    let secret = NSSecureTextField(string: "hunter2")
    let locked = NSButton(title: "Locked", target: nil, action: nil)
    var log = "start"

    /// The timeline mode's controls.
    let timeline = ProcessInfo.processInfo.environment["AUTOMATION_FIXTURE_TIMELINE"] == "1"
    let status = NSTextField(string: "working")
    var late: NSButton?
    var stack: NSStackView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 360, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Automation Fixture"

        let increment = NSButton(title: "Increment", target: self, action: #selector(increment))
        let alert = NSButton(title: "Open Alert", target: self, action: #selector(showAlert))
        name.placeholderString = "Name"
        name.delegate = self
        agree.target = self
        agree.action = #selector(changed)
        size.addItems(withTitles: ["Small", "Medium", "Large…"])
        size.target = self
        size.action = #selector(changed)
        volume.target = self
        volume.action = #selector(changed)
        volume.setAccessibilityLabel("Volume")
        locked.isEnabled = false

        stack = NSStackView(views: [count, increment, alert, name, agree, size, volume, secret, locked])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.frame = NSRect(x: 20, y: 20, width: 320, height: 320)
        window.contentView?.addSubview(stack)

        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let fixtureMenu = NSMenu(title: "Fixture")
        fixtureMenu.addItem(withTitle: "Say Hello", action: #selector(hello), keyEquivalent: "h")
        let disabled = NSMenuItem(title: "Never", action: nil, keyEquivalent: "")
        disabled.isEnabled = false
        fixtureMenu.autoenablesItems = false
        fixtureMenu.addItem(disabled)
        appItem.submenu = fixtureMenu
        NSApp.mainMenu = menu

        if timeline {
            startTimeline()
            report()
            return
        }

        window.makeKeyAndOrderFront(nil)
        // Brought forward, as an app a person launched would be. macOS may
        // refuse — activation is cooperative — and the suite does not depend
        // on it succeeding: everything it drives works in the background.
        NSApp.activate()
        report()
    }

    /// The waiting fixture's schedule, from now.
    func startTimeline() {
        status.placeholderString = "Status"
        stack.addArrangedSubview(status)
        window.orderBack(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
            let button = NSButton(title: "Late", target: nil, action: nil)
            button.isEnabled = false
            stack.addArrangedSubview(button)
            late = button
            log = "late shown"
            report()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [self] in
            late?.isEnabled = true
            log = "late enabled"
            report()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { [self] in
            status.stringValue = "done"
            log = "status done"
            report()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [self] in
            late?.removeFromSuperview()
            late = nil
            log = "late removed"
            report()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [self] in
            // Closed but kept alive, ordered out — what Mail and Notes do with
            // theirs. The window server still lists it, off-screen; it is on
            // no Space, and must not read as being on another one.
            window.isReleasedWhenClosed = false
            window.close()
            log = "window closed"
            report()
        }
    }

    @objc func increment() {
        presses += 1
        count.stringValue = "Count: \(presses)"
        report()
    }

    @objc func showAlert() {
        log = "alert"
        report()
        let alert = NSAlert()
        alert.messageText = "Fixture alert"
        alert.addButton(withTitle: "OK")
        alert.runModal()
        log = "alert closed"
        report()
    }

    @objc func hello() {
        log = "hello"
        report()
    }

    @objc func changed() { report() }

    func controlTextDidChange(_ obj: Notification) { report() }

    /// One line of JSON: everything a test might assert on.
    func report() {
        let state: [String: Any] = [
            "presses": presses,
            "name": name.stringValue,
            "agree": agree.state == .on,
            "size": size.titleOfSelectedItem ?? "",
            "volume": volume.doubleValue,
            "log": log,
            "status": status.stringValue,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) {
            FileHandle.standardOutput.write(data + Data("\n".utf8))
        }
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
let fixture = Fixture()
application.delegate = fixture
application.run()
