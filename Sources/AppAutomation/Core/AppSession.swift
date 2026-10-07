//
//  AppSession.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  One app's interface: read, searched, and — through the extensions —
//  acted on.
//

import AppKit
import ApplicationServices
import Foundation

/// Reading and driving one running app through Accessibility.
///
/// ```swift
/// let finder = try AppSession(matching: "Finder")
/// let snapshot = try finder.snapshot()
/// let button = try finder.resolve(ElementQuery("New Folder", role: "button"))
/// try finder.press(button.ref)
/// ```
///
/// Nothing here holds on to a live element between calls. Every action takes
/// an ``ElementRef``, walks to it fresh and checks it is still the element
/// that was read — so a session can be kept for as long as is convenient, and
/// a ref printed by one process works in the next.
public final class AppSession {

    /// The app this session reads.
    public let app: RunningApp

    /// The app's own Accessibility element.
    let root: AXUIElement

    /// How long to wait for the app to answer one call.
    ///
    /// Three seconds. Accessibility's own default is six, and an app that has
    /// not answered in three is usually showing a modal dialog or hung; either
    /// way a caller is better told than kept waiting twice as long.
    public static let defaultTimeout: Float = 3

    /// Opens a session on a running app.
    ///
    /// - Throws: ``AutomationError/notTrusted`` before anything is read, when
    ///   this process may not use Accessibility.
    public init(_ app: RunningApp, timeout: Float = AppSession.defaultTimeout) throws {
        guard Automation.isTrusted else { throw AutomationError.notTrusted }
        self.app = app
        self.root = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(root, timeout)
    }

    /// Opens a session on the running app a name, bundle identifier or pid
    /// names.
    public convenience init(matching query: String, timeout: Float = AppSession.defaultTimeout) throws {
        try self.init(Automation.app(matching: query), timeout: timeout)
    }

    // MARK: - Reading

    /// The interface, flat, in tree order.
    ///
    /// - Parameters:
    ///   - scope: Which window — the focused one by default.
    ///   - limits: When to stop.
    public func snapshot(_ scope: TreeScope = .focusedWindow, limits: ReadLimits = .standard) throws -> Snapshot {
        try ensureReadable()
        var reader = TreeReader(limits: limits, root: root)
        for (index, element) in try roots(for: scope) {
            reader.read(element, path: [index])
        }
        return Snapshot(app: current, elements: reader.elements, isTruncated: reader.isTruncated)
    }

    /// Every element a query matches, best first.
    public func find(_ query: ElementQuery, in scope: TreeScope = .focusedWindow) throws -> [Element] {
        QueryMatching.select(query, from: try snapshot(scope).elements)
    }

    /// The one element a query means.
    ///
    /// - Throws: ``AutomationError/noSuchElement(_:)`` for none and
    ///   ``AutomationError/ambiguous(_:_:)`` for several. Several is refused
    ///   rather than resolved to the first: the first of two "Delete" buttons
    ///   is a coin toss, and the candidates' refs are what the caller needs to
    ///   choose properly.
    public func resolve(_ query: ElementQuery, in scope: TreeScope = .focusedWindow) throws -> Element {
        let matches = try find(query, in: scope)
        let what = Self.describe(query)
        switch matches.count {
        case 0: throw AutomationError.noSuchElement(what)
        case 1: return matches[0]
        default: throw AutomationError.ambiguous(what, matches)
        }
    }

    /// The element at a ref, read now.
    ///
    /// - Throws: ``AutomationError/stale(_:)`` when something else is there.
    public func element(_ ref: ElementRef) throws -> Element {
        try live(ref).element
    }

    /// The element with keyboard focus in this app, if any.
    public func focusedElement() throws -> Element? {
        try ensureReadable()
        let (value, status) = AXRead.attribute(kAXFocusedUIElementAttribute, of: root)
        if status == .apiDisabled { throw AutomationError.notTrusted }
        guard let focused = AXRead.element(value as AnyObject?) else { return nil }

        // Focused but unreachable from the app's children happens — a field
        // in a popover some apps parent elsewhere. It is still worth
        // describing, under an empty path that will refuse to resolve rather
        // than one that points at something else.
        var reader = TreeReader(limits: .standard, root: root)
        reader.read(focused, path: path(to: focused) ?? [], levels: TreeReader.namingDepth)
        return reader.elements.first
    }

    /// The text in a window, in reading order.
    public func text(_ scope: TreeScope = .focusedWindow) throws -> [String] {
        TextExtraction.lines(from: try snapshot(scope).elements)
    }

    // MARK: - Internals

    /// The app as it is now, rather than when the session opened.
    var current: RunningApp {
        NSRunningApplication(processIdentifier: app.pid).map(RunningApp.init) ?? app
    }

    /// Walks to a ref and checks the fingerprint.
    func live(_ ref: ElementRef) throws -> (element: Element, handle: AXUIElement) {
        try ensureReadable()
        guard let first = ref.path.first else { throw AutomationError.stale(ref) }
        let tops = topLevel()
        guard tops.indices.contains(first), var handle = tops[first] else { throw AutomationError.stale(ref) }
        for index in ref.path.dropFirst() {
            let children = AXRead.children(of: handle)
            guard children.indices.contains(index) else { throw AutomationError.stale(ref) }
            handle = children[index]
        }
        var reader = TreeReader(limits: .standard, root: root)
        reader.read(handle, path: ref.path, levels: TreeReader.namingDepth)
        guard let element = reader.elements.first, element.ref.fingerprint == ref.fingerprint else {
            throw AutomationError.stale(ref)
        }
        return (element, handle)
    }

    /// The starting points every path is counted from: the menu bar at 0,
    /// then each window in `AXWindows` order.
    ///
    /// Not the app's `AXChildren`, which is the obvious choice. Unlocked, the
    /// windows were among the children — the probes walked them — but the
    /// children also hold the menu bar and whatever else an app hangs off
    /// itself, in an order nothing documents. And with the screen locked
    /// they held **the application element itself**, first, so a path
    /// counted through them pointed back at the app. `AXWindows` means
    /// exactly "the windows", which is what a ref is rooted in.
    ///
    /// The menu bar is pinned at 0 so its refs never move when a window
    /// opens. `nil` holds the place of a menu bar an app does not have.
    func topLevel() -> [AXUIElement?] {
        let bar = AXRead.element(AXRead.attribute(kAXMenuBarAttribute, of: root).value as AnyObject?)
        return [bar] + rawWindows().map { Optional($0) }
    }

    /// `AXWindows`, minus the app element itself.
    ///
    /// Which is a thing it holds: on every app measured while the screen was
    /// locked, `AXWindows` listed one element whose role was `AXApplication`
    /// and which was `CFEqual` to the app. Treated as a window, it is the app
    /// read again. Locked reads are refused before they get here; this is the
    /// second line, for whatever else produces the same shape.
    func rawWindows() -> [AXUIElement] {
        let windows = (AXRead.attribute(kAXWindowsAttribute, of: root).value as? [AXUIElement]) ?? []
        return windows.filter { !CFEqual($0, root) }
    }

    /// The top-level elements a scope covers, with their index in
    /// ``topLevel()``.
    func roots(for scope: TreeScope) throws -> [(Int, AXUIElement)] {
        if scope == .menuBar {
            guard let bar = topLevel().first ?? nil else { throw AutomationError.noSuchElement("the menu bar") }
            return [(0, bar)]
        }

        // Checked first, because it says WHY there is nothing: hidden, on
        // another Space, or genuinely no windows.
        let windows = try self.windows()
        let indexed = windows.enumerated().map { ($0.offset + 1, $0.element) }

        switch scope {
        case .allWindows, .menuBar:
            return indexed

        case .window(let title):
            let matching = indexed.filter {
                AXRead.text(AXRead.attribute(kAXTitleAttribute, of: $0.1).value as AnyObject?)?
                    .range(of: title, options: .caseInsensitive) != nil
            }
            guard !matching.isEmpty else { throw AutomationError.noSuchWindow(title) }
            return matching

        case .focusedWindow:
            let focused = [kAXFocusedWindowAttribute, kAXMainWindowAttribute].lazy
                .compactMap { AXRead.element(AXRead.attribute($0, of: self.root).value as AnyObject?) }
                .first
            if let focused, let match = indexed.first(where: { CFEqual($0.1, focused) }) {
                return [match]
            }
            // An app in the background often has no focused or main window
            // to report, and the first of `AXWindows` is not necessarily a
            // window: Finder's is the DESKTOP, an AXScrollArea. A real
            // window first, then whatever there is.
            let real = indexed.first {
                AXRead.text(AXRead.attribute(kAXRoleAttribute, of: $0.1).value as AnyObject?) == "AXWindow"
            }
            return real.map { [$0] } ?? Array(indexed.prefix(1))
        }
    }

    /// The app's windows on this Space, or the reason there are none.
    func windows() throws -> [AXUIElement] {
        if current.isHidden { throw AutomationError.appHidden(app.name) }
        let status = AXRead.attribute(kAXWindowsAttribute, of: root).status
        if status == .apiDisabled { throw AutomationError.notTrusted }
        if status == .cannotComplete { throw AutomationError.timedOut(app.name) }

        let windows = rawWindows()
        guard windows.isEmpty else { return windows }

        let elsewhere = WindowCensus.offscreenWindows(of: app.pid)
        if elsewhere > 0 { throw AutomationError.windowsOnAnotherSpace(app.name, count: elsewhere) }
        throw AutomationError.noWindows(app.name)
    }

    /// Refuses up front when nothing could be read: no permission, or a
    /// locked screen.
    func ensureReadable() throws {
        guard Automation.isTrusted else { throw AutomationError.notTrusted }
        if Automation.isScreenLocked { throw AutomationError.screenLocked }
    }

    /// The path from the app to an element, by walking up its parents until
    /// one of the ``topLevel()`` elements is reached.
    func path(to element: AXUIElement) -> [Int]? {
        let tops = topLevel()
        var path: [Int] = []
        var node = element
        for _ in 0..<200 {
            if let top = tops.firstIndex(where: { $0.map { CFEqual($0, node) } ?? false }) {
                return [top] + path.reversed()
            }
            guard let parent = AXRead.element(AXRead.attribute(kAXParentAttribute, of: node).value as AnyObject?),
                  !CFEqual(parent, root),
                  let index = AXRead.children(of: parent).firstIndex(where: { CFEqual($0, node) })
            else { return nil }
            path.append(index)
            node = parent
        }
        return nil
    }

    /// A query in words, for messages: `button “Save”`.
    static func describe(_ query: ElementQuery) -> String {
        switch (query.role, query.text) {
        case let (role?, text?): return "\(role) “\(text)”"
        case let (nil, text?): return "“\(text)”"
        case let (role?, nil): return role
        case (nil, nil): return "anything"
        }
    }
}
