//
//  floating_aiApp.swift
//  floating-ai
//
//  Created by Federico Vitale on 03/11/23.
//

import SwiftUI
import SwiftData
import HotKey
import OpenAI

@main
struct floating_aiApp: App {
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

    
    let activationHotKey = HotKey(key: .a, modifiers: [.command, .option], keyUpHandler:  {
        if !NSApp.isHidden {
            NSApp.hide(nil)
        } else {
            NSApp.activate()
        }
    })

    var body: some Scene {
        Settings {
            SettingsView()
        }
        Window("Floating AI", id: "main-window") {
            ChatsList(chatStore: .init())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.topLeading)
        
        .modelContainer(sharedModelContainer)
    }
}
