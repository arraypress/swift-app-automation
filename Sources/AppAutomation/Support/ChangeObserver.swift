//
//  ChangeObserver.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  Hearing about changes in another app instead of only looking.
//

import ApplicationServices
import Foundation

/// Accessibility notifications from one app, as a pause that ends early.
///
/// Registered once, on the app's own element: measured on TextEdit, every
/// notification below registered there, and a window opening (`AXCreated`,
/// `AXWindowCreated`) and closing (fourteen `AXUIElementDestroyed`) were both
/// delivered to that one registration — none needed registering per element.
///
/// **A notification is a hint, never an answer.** It says "look again", and
/// the wait looks; nothing is concluded from which notification arrived or
/// from what it was about. Apps differ in what they send, and polling carries
/// on beside this whatever they send.
///
/// The run-loop source lives on the thread that made this, and the pause runs
/// that thread's run loop — so make it, pause it and drop it on one thread,
/// without suspending in between.
final class ChangeObserver {

    /// What is listened for: things appearing, going, changing value or name,
    /// moving focus, and the app hiding or showing.
    static let notifications: [String] = [
        kAXCreatedNotification,
        kAXUIElementDestroyedNotification,
        kAXValueChangedNotification,
        kAXTitleChangedNotification,
        kAXWindowCreatedNotification,
        kAXFocusedWindowChangedNotification,
        kAXMainWindowChangedNotification,
        kAXFocusedUIElementChangedNotification,
        kAXLayoutChangedNotification,
        kAXSelectedChildrenChangedNotification,
        kAXSelectedRowsChangedNotification,
        kAXRowCountChangedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
        kAXApplicationHiddenNotification,
        kAXApplicationShownNotification,
        kAXElementBusyChangedNotification,
    ]

    private let observer: AXObserver
    private let element: AXUIElement
    private let source: CFRunLoopSource
    private let runLoop: CFRunLoop
    private var registered: [String] = []

    /// Notifications heard so far.
    private(set) var heard = 0

    /// Starts listening to an app, or `nil` when it accepted none of the
    /// registrations — in which case a wait polls.
    init?(pid: pid_t, element: AXUIElement) {
        var created: AXObserver?
        // A C callback captures nothing; the observer finds its way back to
        // this object through the refcon, unretained — `deinit` removes every
        // registration before the object goes.
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            Unmanaged<ChangeObserver>.fromOpaque(refcon).takeUnretainedValue().heard += 1
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return nil }
        observer = created
        self.element = element
        source = AXObserverGetRunLoopSource(created)
        runLoop = CFRunLoopGetCurrent()

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.notifications {
            let status = AXObserverAddNotification(created, element, name as CFString, refcon)
            if status == .success { registered.append(name) }
            // Not answering — still launching, or hung. Asking sixteen more
            // times would cost a messaging timeout each.
            if status == .cannotComplete { break }
        }
        guard !registered.isEmpty else {
            // deinit removes what was registered; there is nothing.
            return nil
        }
        CFRunLoopAddSource(runLoop, source, .defaultMode)
    }

    deinit {
        for name in registered {
            AXObserverRemoveNotification(observer, element, name as CFString)
        }
        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
        CFRunLoopSourceInvalidate(source)
    }

    /// Waits up to `seconds`, returning early — `true` — when the app sends a
    /// notification.
    func pause(_ seconds: TimeInterval) -> Bool {
        guard seconds > 0 else { return false }
        let before = heard
        // Returns after the first source handled, or when the time is up.
        // Another source on this run loop can end it early too, which is why
        // the count decides rather than the result.
        _ = CFRunLoopRunInMode(.defaultMode, seconds, true)
        return heard > before
    }
}
