//
//  ChatsList.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import SwiftUI
import Combine

final class NotificationPublisher: ObservableObject {
    enum Event: Hashable {
        case ChatRenamed(String)
    }
    
    let event: AnyPublisher<Event, Never>
    private let subject = PassthroughSubject<Event, Never>()
    
    init() {
        event = subject.eraseToAnyPublisher()
    }
    
    func send(_ event: Event) {
        self.subject.send(event)
    }
}

struct ChatsList: View {
    @ObservedObject var chatStore: ChatStore
    @State var text: String = ""
    @State var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    
    @State var notificationContent: String?
    
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
                    ZStack(alignment: .leading) {
                        Text(conversation.name)
                        
                        if chatStore.loadingMap[conversation.id] == true {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .controlSize(.mini)
                                .transition(.opacity)
                                .padding(.leading, 5)
                        }
                        
                    }
                }
            }
            .toolbar(removing: chatStore.conversations.isEmpty ? .sidebarToggle : nil)
        } detail: {
            if let conversation = chatStore.selectedConversation {
                let isLoading = chatStore.loadingMap[conversation.id] ?? false
                
                ZStack(alignment: .top) {
                    HStack {
                        if let notificationContent = self.notificationContent {
                            Spacer()
                            NotificationBubble(text: notificationContent)
                            Spacer()
                        }
                    }
                    .padding(.top, 30)
                    .animation(.easeInOut, value: self.notificationContent)
                    .zIndex(10)
                    .onReceive(self.chatStore.notificationsPublisher.event) { event in
                        switch event {
                        case NotificationPublisher.Event.ChatRenamed(_):
                            self.notificationContent = "Conversation renamed"
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                self.notificationContent = nil
                            }
                            break
                        }
                    }
                    
                    Spacer()
                    ZStack(alignment: .bottom) {
                        ScrollViewReader { scrollView in
                            ScrollView {
                                VStack {
                                    ForEach(conversation.visibleMessages) { message in
                                        ChatBubble(message: message)
                                    }
                                }
                                .padding(.top, 20)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 80)
                                
                                if let error = chatStore.conversationErrors[conversation.id] {
                                    HStack(alignment: .center) {
                                        Spacer()
                                        Text(error.localizedDescription)
                                            .foregroundStyle(.red)
                                            .font(.system(size: 14).monospaced())
                                        Spacer()
                                    }
                                }
                            }
                            .id(UUID())
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
                                isLoading ? "Please wait..." : "Ask AI anything..",
                                text: $text,
                                isLoading: isLoading,
                                isEmpty: conversation.messages.isEmpty
                            ) {
                                let content = self.text;
                                self.text = ""
                                self.chatStore.sendMessage(.user(conversation.id, content))
                                
//                                Task {
//                                    await chatStore.sendMessage(
//                                        .user(conversation.id, content)
//                                    )
//                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .navigationTitle(conversation.name)
            } else {
                VStack(alignment: .trailing) {
                    Spacer()
                    EmptyPlaceholder()
                    Spacer()
                    
                    ChatTextField(
                        chatStore.isLoading ? "Please wait..." : "Ask AI anything..",
                        text: $text,
                        isLoading: false,
                        isEmpty: true
                    ) {
                        let conversationId = chatStore.createConversation()
                        
                        let content = self.text
                        self.text = ""
                        chatStore.selectConversation(conversationId)
                        
                        self.chatStore.sendMessage(.user(conversationId, content))
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
                    let selectedId = chatStore.selectedConversationID;
                    chatStore.deleteConversation(selectedId)
                    
                    if let lastConversation = chatStore.conversations.last(where: {
                        $0.id != selectedId
                    }) {
                        chatStore.selectConversation(lastConversation.id)
                    }
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
        .onAppear {
            withAnimation {
                self.columnVisibility = .detailOnly
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


#Preview {
    ChatsList(chatStore: .init())
}
