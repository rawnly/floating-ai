//
//  ChatsList.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import SwiftUI

struct ChatsList: View {
    @ObservedObject var chatStore: ChatStore
    @State var text: String = ""
    @State var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State var isLoading = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: Binding<Conversation.ID?>(
                get: {
                    chatStore.selectedConversationID
                },
                set: { id in
                    chatStore.selectConversation(id)
                }
            )) {
                ForEach($chatStore.conversations, id: \.id) { $conversation in
                    Text(conversation.name)
                }
            }
            .toolbar(removing: chatStore.conversations.isEmpty ? .sidebarToggle : nil)
        } detail: {
            if let conversation = chatStore.selectedConversation {
                ZStack(alignment: .bottom) {
                    ScrollViewReader { scrollView in
                        ScrollView {
                            LazyVStack(alignment: .leading) {
                                ForEach(conversation.visibleMessages, id: \.id) { message in
                                    ChatMessageView(message.content, style: message.role)
                                }
                            }
                            .id(UUID())
                        }
                        .onAppear {
                            guard let lastMessage = conversation.visibleMessages.last else { return }
                            
                            withAnimation(.easeInOut) {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                        //                        .onChange(of: conversation.visibleMessages) { _, _ in
                        //                            guard let lastMessage = conversation.visibleMessages.last else { return }
                        //                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        //                        }
                        .background(.clear)
                        .cornerRadius(8)
                    }
                    .zIndex(0)
                    
                    VStack(alignment: .trailing) {
                        if conversation.messages.isEmpty {
                            Spacer()
                            EmptyPlaceholder()
                            Spacer()
                        }
                        
                        ChatTextField(
                            chatStore.isLoading ? "Please wait..." : "Ask AI anything..",
                            text: $text,
                            isLoading: chatStore.isLoading,
                            isEmpty: conversation.messages.isEmpty
                        ) {
                            let message = Message(
                                id: UUID().uuidString,
                                kind: .user,
                                chat_id: conversation.id,
                                self.text
                            )
                            self.text = ""
                            
                            Task {
                                await chatStore.sendMessage(message, conversationId: conversation.id)
                            }
                        }
                    }
                }
                .padding(20)
                .navigationTitle(conversation.name)
            } else {
                VStack(alignment: .trailing) {
                    Spacer()
                    EmptyPlaceholder()
                    Spacer()
                    
                    ChatTextField(
                        chatStore.isLoading ? "Please wait..." : "Ask AI anything..",
                        text: $text,
                        isLoading: chatStore.isLoading,
                        isEmpty: true

                    ) {
                        let conversationId = chatStore.createConversation()
                        
                        let message = Message(
                            id: UUID().uuidString,
                            kind: .user,
                            chat_id: conversationId,
                            self.text
                        )
                        self.text = ""
                        chatStore.selectConversation(conversationId)
                        
                        Task {
                            await chatStore.sendMessage(message, conversationId: conversationId)
                        }
                    }
                }
                .padding(20)
            }
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(chatStore.selectedConversation?.name ?? "Floating AI")
                    .font(.title3)
                    .bold()
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                
                Button(action: {
                    chatStore.clearActiveConversation(chatStore.selectedConversationID)
                }) {
                    Label("Clear Conversation", systemImage: "eraser")
                }
                .disabled(chatStore.selectedConversationID == nil)
                
                Button(action: {
                    let lastConversationId = chatStore.conversations.last?.id
                    chatStore.deleteConversation(chatStore.selectedConversationID)
                    chatStore.selectConversation(lastConversationId)
                    self.columnVisibility = .detailOnly
                }) {
                    Label("Delete Conversation", systemImage: "trash")
                }
                .disabled(chatStore.selectedConversationID == nil)
            }
            
            ToolbarItemGroup (placement: .navigation){
                SettingsLink {
                    Label("Open Preferences", systemImage: "gear")
                }
                
                Button(action: {
                    let id = chatStore.createConversation()
                    chatStore.selectConversation(id)
                }) {
                    Label("Add Conversation", systemImage: "plus")
                }
            }
        }
    }
}



struct EmptyPlaceholder: View {
    var body: some View {
        HStack {
            Spacer()
            VStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.secondary)
                    .padding(.vertical, 8)
                
                Text("Ask AI Anything")
                    .bold()
                    .font(.system(size: 24))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .foregroundStyle(Color.secondary)
                    .padding(.bottom, 4)
                
                VStack {
                    Text("\"Convert the following Python function to TypesScript\"")
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .foregroundStyle(Color.secondary.opacity(0.7))
                    
                    Text("\"How old is the Pope?\"")
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .foregroundStyle(Color.secondary.opacity(0.7))
                    
                    Text("\"Who is the president of the USA?\"")
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }
            }
            Spacer()
        }
    }
}


