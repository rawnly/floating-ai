//
//  floating_aiApp.swift
//  floating-ai
//
//  Created by Federico Vitale on 03/11/23.
//

import SwiftUI
import SwiftData
import HotKey
import KeyboardShortcuts
import OpenAI


@main
struct FloatingAIApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var permissionService  = PermissionsService()
    
    @State private var isAlertOpen: Bool = false;
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()


    var body: some Scene {
        Window("Floating AI", id: "chat") {
            ChatsList(chatStore: self.appDelegate.chatStore)
                ._visualEffect(material: .sidebar)
                .onAppear {
                    self.permissionService.pollAccessibilityPrivileges(shouldPrompt: true)
                }
                .frame(minWidth: 400, minHeight: 500)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 300, height: 600)
        .defaultPosition(.topTrailing)
        
        Settings {
            SettingsView()
                .navigationTitle("Preferences")
                .frame(width: 600, height: 400)
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

@MainActor
final class AppState: ObservableObject {
    init() {
        KeyboardShortcuts.onKeyDown(for: .activateApp) {
            print(NSApp.isHidden, NSApp.isActive)
            if NSApp.isActive {
                NSApplication.shared.hide(nil)
            } else if NSApp.isHidden {
                NSApplication.shared.activate()
            } else if !NSApp.isActive && !NSApp.isHidden {
                NSApplication.shared.activate()
                
                guard let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "chat" }) else {
                    return
                }
                
                window.makeKeyAndOrderFront(nil)
                window.makeMain()
                FocusWindow.focusWindow(name: "Floating AI")
            }
        }
    }
}

