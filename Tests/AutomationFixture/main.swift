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

        let stack = NSStackView(views: [count, increment, alert, name, agree, size, volume, secret, locked])
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

        window.makeKeyAndOrderFront(nil)
        // Brought forward, as an app a person launched would be. macOS may
        // refuse — activation is cooperative — and the suite does not depend
        // on it succeeding: everything it drives works in the background.
        NSApp.activate()
        report()
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
