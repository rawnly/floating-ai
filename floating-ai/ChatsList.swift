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
                    EditableLabel(
                        label: conversation.messages.last?.content ?? "New Conversation"
                    ) { name in
                        chatStore.updateConversationName(conversation.id, name: name)
                    }
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
                ZStack(alignment: .bottom) {
                    ScrollViewReader { scrollView in
                        ScrollView {
                            LazyVStack(alignment: .leading) {
                                ForEach(conversation.messages, id: \.id) { message in
                                    ChatMessageView(message.content, style: message.role)
                                }
                            }
                            .id(UUID())
                        }
                        .onAppear {
                            guard let lastMessage = conversation.messages.last else { return }
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        .onChange(of: conversation.messages) { _, _ in
                            guard let lastMessage = conversation.messages.last else { return }
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        .background(.clear)
                        .cornerRadius(8)
                    }
                    .zIndex(0)
                    
                    LazyVStack(alignment: .leading) {
                        if conversation.messages.isEmpty {
                            Spacer()
                            Text("Press enter to submit")
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .foregroundStyle(Color.secondary.opacity(0.5))
                                .zIndex(2)
                            Spacer()
                        }
                        
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
                }
                .padding(20)
            } else {
                VStack(alignment: .trailing) {
                    Spacer()
                    VStack {
                        Text("Press enter to submit")
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .zIndex(2)
                        ChatTextField(
                            chatStore.isLoading ? "Please wait..." : "Ask AI anything..",
                            text: $text,
                            isLoading: chatStore.isLoading
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
                }
                .padding(20)
            }
        }
    }
}

