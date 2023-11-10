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
    @ObservedObject
    public var chatStore: ChatStore = ChatStore()

    @StateObject private var appState = AppState()
    @StateObject private var permissionService = PermissionsService()
    
    @State var hostingWindow: NSWindow?
    @State private var isAlertOpen: Bool = false;
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Preference(\.floatingWindow)
    var floating
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // TODO: Init Sentry here
        self.chatStore.load()
    }

    var body: some Scene {
        Window("Floating AI", id: "chat") {
            ChatsList()
                .onAppear {
                    self.permissionService.pollAccessibilityPrivileges(shouldPrompt: true)
                }
                .frame(minWidth: 400, minHeight: 500)
                .environmentObject(appState)
                .environmentObject(chatStore)
                .environmentObject(permissionService)
                .bindHostingWindow(self.$hostingWindow)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 300, height: 600)
        .defaultPosition(.topTrailing)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Conversation") {
                    let id = self.chatStore.createConversation()
                    self.chatStore.selectConversation(id)
                }
            }
            
            CommandGroup(after: .windowSize) {
                Toggle("Floating Window", isOn: self.$floating)
            }
            
            CommandGroup(replacing: .help) {
                Link("Twitter", destination: URL(string: "https://twitter.com/fedevitaledev")!)
                Link("Author Github", destination: URL(string: "https://github.com/rawnly")!)
            }
        }
        
        
        Settings {
            SettingsView(chatStore: self.chatStore)
                .navigationTitle("Preferences")
                .frame(width: 600, height: 400)
                .environmentObject(appState)
                .environmentObject(permissionService)
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
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

