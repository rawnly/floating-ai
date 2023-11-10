//
//  AppDelegate.swift
//  floating-ai
//
//  Created by Federico Vitale on 05/11/23.
//

import Foundation
import SwiftUI

extension NSToolbarItem.Identifier {
    static let toggleSidebarVisibility: String = "ToggleSidebarVisibility"
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var toolbar: NSToolbar!
    private var toolbarItems: [[String:String]] = [
        ["title": "Share", "icon": "gear", "identifier": NSToolbarItem.Identifier.toggleSidebarVisibility]
    ]
    
    var toolbarIdentifiers: [NSToolbarItem.Identifier] {
        toolbarItems
            .compactMap { $0["identifier"] }
            .map { NSToolbarItem.Identifier($0) }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        toolbar = NSToolbar(identifier: NSToolbar.Identifier("MainToolbar"))
        toolbar.allowsUserCustomization = false
        toolbar.delegate = self
        
        NSApp.setActivationPolicy(Preferences.standard.showDockIcon ? .regular : .accessory)
    }
    
    @objc
    func toggleSidebarVisibility(_ sender: NSToolbarItem?) {
        print("TOGGLE")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionsService.acquireAccessibilityPrivileges()
        
        guard let window = NSApplication.shared.windows.first else {
            return
        }
        
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.contentView?.wantsLayer = true
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        
        if Preferences.standard.floatingWindow {
            window.level = .modalPanel
        }
        
        window.makeMain()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print(notification)
    }
    
    func updateActivationPolicy(to policy: NSApplication.ActivationPolicy) {
            NSApp.setActivationPolicy(policy)
            NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let dict = toolbarItems.filter({ $0["identiifer"]! == itemIdentifier.rawValue }).first else { return nil }
        
        let toolbarItem: NSToolbarItem?
        
        switch itemIdentifier.rawValue {
        case NSToolbarItem.Identifier.toggleSidebarVisibility:
            toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
            toolbarItem!.label = dict["title"]!
            return toolbarItem
        default:
            break
        }
        
        
        return nil
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return self.toolbarIdentifiers
    }
}
