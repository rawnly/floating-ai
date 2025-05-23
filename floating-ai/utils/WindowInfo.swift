//
//  WindowInfo.swift
//  Floating AI
//
//  Created by Federico Vitale on 08/11/23.
//

import Foundation
import AppKit
import Cocoa
import SwiftUI

/**
Static representation of a window.

- Note: The `name` property is always `nil` on macOS 10.15 and later unless you request “Screen Recording” permission.
*/
struct WindowInfo {
    struct Owner {
        let name: String
        let processIdentifier: Int
        let bundleIdentifier: String?
        let app: NSRunningApplication?
    }

    // Most of these keys are guaranteed to exist: https://developer.apple.com/documentation/coregraphics/quartz_window_services/required_window_list_keys

    let identifier: CGWindowID
    let name: String?
    let owner: Owner
    let bounds: CGRect
    let layer: Int
    let alpha: Double
    let memoryUsage: Int
    let sharingState: CGWindowSharingType // https://stackoverflow.com/questions/27695742/what-does-kcgwindowsharingstate-actually-do
    let isOnScreen: Bool
    let fillsScreen: Bool

    /**
    Accepts a window dictionary coming from `CGWindowListCopyWindowInfo`.
    */
    private init(windowDictionary window: [String: Any]) {
        self.identifier = window[kCGWindowNumber as String] as! CGWindowID
        self.name = window[kCGWindowName as String] as? String

        let processIdentifier = window[kCGWindowOwnerPID as String] as! Int
        let app = NSRunningApplication(processIdentifier: pid_t(processIdentifier))

        self.owner = Owner(
            name: window[kCGWindowOwnerName as String] as? String ?? app?.localizedTitle ?? "<Unknown>",
            processIdentifier: processIdentifier,
            bundleIdentifier: app?.bundleIdentifier,
            app: app
        )

        let bounds = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!

        self.bounds = bounds
        self.layer = window[kCGWindowLayer as String] as! Int
        self.alpha = window[kCGWindowAlpha as String] as! Double
        self.memoryUsage = window[kCGWindowMemoryUsage as String] as? Int ?? 0
        self.sharingState = CGWindowSharingType(rawValue: window[kCGWindowSharingState as String] as! UInt32)!
        self.isOnScreen = (window[kCGWindowIsOnscreen as String] as? Int)?.boolValue ?? false
        self.fillsScreen = NSScreen.screens.contains { $0.frame == bounds }
    }
}

extension WindowInfo {
    typealias Filter = (Self) -> Bool

    private static let appIgnoreList = [
        "com.apple.dock",
        "com.apple.notificationcenterui",
        "com.apple.screencaptureui",
        "com.apple.PIPAgent",
        "com.sindresorhus.Pasteboard-Viewer",
        "co.hypercritical.SwitchGlass", // Dock replacement
        "app.macgrid.Grid", // https://macgrid.app
        "com.edge.LGCatalyst", // https://apps.apple.com/app/id1602004436 - It adds a floating player.
        "com.replay.sleeve" // https://replay.software/sleeve - It adds a floating player.
    ]

    /**
    Filters out fully transparent windows and windows smaller than 50 width or height.
    */
    static func defaultFilter(window: Self) -> Bool {
        let minimumWindowSize = 50.0

        // Skip windows outside the expected level range.
        guard
            window.layer < NSWindow.Level.mainMenu.rawValue,
            window.layer >= NSWindow.Level.normal.rawValue
        else {
            return false
        }

        // Skip fully transparent windows, like with Chrome.
        // We consider everything below 0.2 to be fully transparent.
        guard window.alpha > 0.2 else {
            return false
        }

        if
            window.alpha < 0.5,
            window.fillsScreen
        {
            return false
        }

        // Skip tiny windows, like the Chrome link hover statusbar.
        guard
            window.bounds.width >= minimumWindowSize,
            window.bounds.height >= minimumWindowSize
        else {
            return false
        }

        // You might think that we could simply skip windows that are `window.owner.app?.activationPolicy != .regular`, but menu bar apps are `.accessory`, and they might be the source of some copied data.
        guard !window.owner.name.lowercased().hasSuffix("agent") else {
            return false
        }

        if let bundleIdentifier = window.owner.bundleIdentifier {
            if Self.appIgnoreList.contains(bundleIdentifier) {
                return false
            }

            let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            let grammarly = "com.grammarly.ProjectLlama"

            // Grammarly puts some hidden window above all other windows. Ignore that.
            if
                bundleIdentifier == grammarly,
                frontmostApp != grammarly
            {
                return false
            }
        }

        return true
    }

    static func allWindows(
        options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements],
        filter: Filter = defaultFilter
    ) -> [Self] {
        let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return info.map { self.init(windowDictionary: $0) }.filter(filter)
    }
}

extension WindowInfo {
    struct UserApp: Hashable, Identifiable {
        let url: URL
        let bundleIdentifier: String

        var id: URL { url }
    }

    /**
    Returns the URL and bundle identifier of the app that owns the frontmost window.

    This method returns more correct results than `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`. For example, the latter cannot correctly detect the 1Password Mini window.
    */
    static func appOwningFrontmostWindow() -> UserApp? {
        func createApp(_ runningApp: NSRunningApplication?) -> UserApp? {
            guard
                let runningApp,
                let url = runningApp.bundleURL,
                let bundleIdentifier = runningApp.bundleIdentifier
            else {
                return nil
            }

            return UserApp(url: url, bundleIdentifier: bundleIdentifier)
        }

        guard
            let app = (
                allWindows()
                    // TODO: Use `.firstNonNil()` here when available.
                    .lazy
                    .compactMap { createApp($0.owner.app) }
                    .first
            )
        else {
            return createApp(NSWorkspace.shared.frontmostApplication)
        }

        return app
    }
}

extension BinaryInteger {
    var boolValue: Bool { self != 0 }
}


extension NSRunningApplication {
    /**
    Like `.localizedName` but guaranteed to return something useful even if the name is not available.
    */
    var localizedTitle: String {
        localizedName
            ?? executableURL?.deletingPathExtension().lastPathComponent
            ?? bundleURL?.deletingPathExtension().lastPathComponent
            ?? bundleIdentifier
            ?? (processIdentifier == -1 ? nil : "PID\(processIdentifier)")
            ?? "<Unknown>"
    }
}



private struct WindowAccessor: NSViewRepresentable {
    private final class WindowAccessorView: NSView {
        @Binding var windowBinding: NSWindow?

        init(binding: Binding<NSWindow?>) {
            self._windowBinding = binding
            super.init(frame: .zero)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            windowBinding = window
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    @Binding var window: NSWindow?

    init(_ window: Binding<NSWindow?>) {
        self._window = window
    }

    func makeNSView(context: Context) -> NSView {
        WindowAccessorView(binding: $window)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /**
    Bind the native backing-window of a SwiftUI window to a property.
    */
    func bindHostingWindow(_ window: Binding<NSWindow?>) -> some View {
        background(WindowAccessor(window))
    }
}

private struct WindowViewModifier: ViewModifier {
    @State private var window: NSWindow?

    let onWindow: (NSWindow?) -> Void

    func body(content: Content) -> some View {
        // We're intentionally not using `.onChange` as we need it to execute for every SwiftUI change as the window properties can be changed at any time by SwiftUI.
        onWindow(window)

        return content
            .bindHostingWindow($window)
    }
}

extension View {
    /**
    Access the native backing-window of a SwiftUI window.
    */
    func accessHostingWindow(_ onWindow: @escaping (NSWindow?) -> Void) -> some View {
        modifier(WindowViewModifier(onWindow: onWindow))
    }

    /**
    Set the window level of a SwiftUI window.
    */
    func windowLevel(_ level: NSWindow.Level) -> some View {
        accessHostingWindow {
            $0?.level = level
        }
    }

    /**
    Set the window tabbing mode of a SwiftUI window.
    */
    func windowTabbingMode(_ tabbingMode: NSWindow.TabbingMode) -> some View {
        accessHostingWindow {
            $0?.tabbingMode = tabbingMode
        }
    }
}
