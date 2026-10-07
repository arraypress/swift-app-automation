//
//  AppSession+Menus.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  The menu bar, as paths.
//
//  Menus are where most of an app's commands live and the one part of its
//  interface that is the same shape in every app, so they get their own
//  reader: `File > New Folder` is a better handle on a command than a ref,
//  because it survives every relaunch and every window.
//
//  A MENU DOES NOT HAVE TO BE OPEN TO BE CHOSEN. Measured on the fixture:
//  pressing a menu item through Accessibility, with its menu closed, ran the
//  item's action and nothing appeared on screen.
//

import ApplicationServices
import Foundation

public extension AppSession {

    /// Every item in the app's menu bar, as paths.
    ///
    /// - Parameter depth: How many levels of submenu to follow. Three covers
    ///   `View > Sort By > Name`; deeper menus are rare and slow to read.
    func menuItems(depth: Int = 3) throws -> [MenuItem] {
        try ensureReadable()
        let bar = try menuBar()
        var items: [MenuItem] = []
        for top in AXRead.children(of: bar) {
            guard let title = Self.title(of: top) else { continue }
            collect(under: top, path: [title], depth: depth, into: &items)
        }
        return items
    }

    /// Chooses a menu item by its path.
    ///
    /// ```swift
    /// try finder.chooseMenu(["File", "New Folder"])
    /// ```
    ///
    /// - Throws: ``AutomationError/noSuchMenuItem(_:)`` or
    ///   ``AutomationError/menuItemDisabled(_:)`` — a disabled item is
    ///   refused rather than pressed, because pressing one does nothing and
    ///   says nothing.
    @discardableResult
    func chooseMenu(_ path: [String]) throws -> ActionResult {
        guard !path.isEmpty else { throw AutomationError.noSuchMenuItem("an empty path") }
        try ensureReadable()
        let written = MenuPath.format(path)

        let bar = try menuBar()
        // The menu bar is always 0 among the top-level elements.
        var refPath = [0]
        var node = bar
        for (depth, step) in path.enumerated() {
            // Below the menu bar, each item's children are a single AXMenu,
            // and the items are the menu's children. Step through it.
            let container = depth == 0 ? node : (AXRead.children(of: node).first ?? node)
            if depth > 0 { refPath.append(0) }

            let children = AXRead.children(of: container)
            guard let index = children.firstIndex(where: {
                Self.title(of: $0).map { MenuPath.matches(step, title: $0) } ?? false
            }) else { throw AutomationError.noSuchMenuItem(written) }
            refPath.append(index)
            node = children[index]
        }

        var reader = TreeReader(limits: .standard, root: root)
        reader.read(node, path: refPath, levels: 0)
        guard let element = reader.elements.first else { throw AutomationError.noSuchMenuItem(written) }
        guard element.isEnabled else { throw AutomationError.menuItemDisabled(written) }

        let status = AXUIElementPerformAction(node, kAXPressAction as CFString)
        var note: String?
        switch status {
        case .success:
            break
        case .cannotComplete:
            note = "\(app.name) did not answer in time — the command may have opened a dialog"
        default:
            throw AXFailure.error(status, doing: "choosing \(written)")
        }
        return ActionResult(element: element, action: "menu", method: .press, note: note)
    }

    // MARK: - Reading menus

    /// The app's menu bar element.
    private func menuBar() throws -> AXUIElement {
        let (value, status) = AXRead.attribute(kAXMenuBarAttribute, of: root)
        if status == .apiDisabled { throw AutomationError.notTrusted }
        guard let bar = AXRead.element(value as AnyObject?) else {
            throw AutomationError.noSuchElement("a menu bar in \(app.name)")
        }
        return bar
    }

    /// Walks one menu, appending its items.
    private func collect(under item: AXUIElement, path: [String], depth: Int, into items: inout [MenuItem]) {
        guard depth > 0, let menu = AXRead.children(of: item).first else { return }
        for child in AXRead.children(of: menu) {
            let values = AXRead.values(of: child, names: [
                kAXTitleAttribute, kAXEnabledAttribute, kAXMenuItemMarkCharAttribute,
                kAXMenuItemCmdCharAttribute, kAXMenuItemCmdModifiersAttribute, kAXChildrenAttribute,
            ])
            // Separators are items with no title.
            guard let title = Labeling.clean(AXRead.text(values[kAXTitleAttribute])) else { continue }

            let hasSubmenu = !((values[kAXChildrenAttribute] as? [AXUIElement]) ?? []).isEmpty
            let modifiers = (values[kAXMenuItemCmdModifiersAttribute] as? NSNumber)?.intValue ?? 0
            items.append(MenuItem(
                path: path + [title],
                isEnabled: AXRead.bool(values[kAXEnabledAttribute]) ?? true,
                isChecked: Labeling.clean(AXRead.text(values[kAXMenuItemMarkCharAttribute])) != nil,
                shortcut: MenuShortcut.format(
                    character: Labeling.clean(AXRead.text(values[kAXMenuItemCmdCharAttribute])),
                    modifiers: modifiers
                ),
                hasSubmenu: hasSubmenu
            ))
            if hasSubmenu { collect(under: child, path: path + [title], depth: depth - 1, into: &items) }
        }
    }

    /// A menu or menu bar item's title.
    private static func title(of element: AXUIElement) -> String? {
        Labeling.clean(AXRead.text(AXRead.attribute(kAXTitleAttribute, of: element).value as AnyObject?))
    }
}
