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
    @State var isLoading = false
    
    func sendMessage(_ message: Message, conversationId: Conversation.ID) async {
        await chatStore.sendMessage(message, conversationId: conversationId)
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: Binding<Conversation.ID?>(
                get: {
                    chatStore.selectedConversationID
                },
                set: { id in
                    chatStore.selectConversation(id)
                }
            )) {
                ForEach($chatStore.conversations, id: \.id) { $conversation in
                    Text(conversation.messages.last?.content ?? "New Conversation")
                        .lineLimit(1)
                }
            }
            .toolbar {
                ToolbarItem(
                    placement: .primaryAction) {
                        Button(action: {
                            let id = chatStore.createConversation()
                            chatStore.selectConversation(id)
                        }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
            }
            
        } detail: {
            if let conversation = chatStore.selectedConversation {
                VStack(alignment: conversation.messages.isEmpty ? .center : .trailing) {
                    if conversation.messages.isEmpty {
                        Spacer()
                        Text("No messages yet.")
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .zIndex(2)
                        Spacer()
                    }
                    
                    List {
                        ForEach(conversation.messages, id: \.id) { message in
                            ChatMessageView(message.content, style: message.role)
                        }
                    }
                    .id(UUID())
                    .zIndex(0)
                    
//                    ScrollViewReader { scrollView in
//                        ScrollView {
//                            LazyVStack(alignment: .leading) {
//                                ForEach(conversation.messages, id: \.id) { message in
//                                    ChatMessageView(message.content, style: message.role)
//                                }
//                            }
//                            .id(UUID())
//                        }
//                        .onAppear {
//                            guard let lastMessage = conversation.messages.last else { return }
//                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
//                        }
//                        .onChange(of: conversation.messages) { _, _ in
//                            guard let lastMessage = conversation.messages.last else { return }
//                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
//                        }
//                        .background(.clear)
//                        .cornerRadius(8)
//                    }
//                    .zIndex(0)
                    
                    HStack {
                        ChatTextField(
                            chatStore.isLoading ? "Please wait..." : "Ask AI anything..",
                            text: $text,
                            isLoading: chatStore.isLoading
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
                    ._visualEffect(material: .sidebar)
                    .zIndex(1)
                }
                .padding(20)
            }
        }
    }
}

