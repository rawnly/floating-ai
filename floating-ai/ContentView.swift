//
//  ContentView.swift
//  floating-ai
//
//  Created by Federico Vitale on 03/11/23.
//

import SwiftUI
import SwiftData
import OpenAI
import Combine


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var chats: [Conversation]
    
    let openAI = OpenAI(apiToken: "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")
    
    var body: some View {
        NavigationSplitView {
            List {
                ForEach(Array(chats.enumerated()), id: \.offset) { idx, chat in
                    NavigationLink {
                        ChatView(chat, onChatRename: { id, name in
                            print(id, name)
                        } ) { _, messages in
                            self.chats[idx].messages = messages
                        }
                    } label: {
                        Text(chat.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Chats")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
        }
        .onAppear {
            for window in NSApplication.shared.windows {
                if window.identifier!.rawValue == "main-window" {
                    window.level = .floating
                }
            }
        }
    }
        

    private func addItem() {
        withAnimation {
            let chat = Conversation()
            modelContext.insert(chat)
        }
    }
    

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(chats[index])
            }
        }
    }
}

