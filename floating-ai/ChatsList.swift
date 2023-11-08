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

struct ErrorMessage: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            Text(self.text)
                .foregroundStyle(.red)
                .font(.system(size: 12).monospaced())
                .padding()
                .textSelection(.enabled)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Spacer()
        }
    }
}

struct ChatsList: View {
    @ObservedObject var chatStore: ChatStore
    @State var isShowingInfo: Bool = false
    @State var text: String = ""
    @State var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    
    @State var notificationContent: String?
    
    @State var showClearConversationAlert: Bool = false
    @State var showDeleteConversationAlert: Bool = false
    @State var renamingChatId: Conversation.ID? = nil
    @State var renamingText: String = ""
    @FocusState var renamingFieldFocus
    
    @Preference(\.apiKey)
    var apiKey
    
    var inputPlaceholder: String {
        if apiKey.isEmpty {
            return "Please provide a valid api key"
        }
        
        return "Ask AI anything..."
    }
    
    private func deleteConversation(conversationId: Conversation.ID?) {
        let isCurrent = self.chatStore.selectedConversationID == conversationId
        
        if isCurrent {
            guard let index = self.chatStore.selectedConversationIndex else { return }
            if index > 0 {
                let previous = self.chatStore.conversations[index - 1]
                self.chatStore.selectConversation(previous.id)
            } else if self.chatStore.conversations.count > index + 1 {
                let next = self.chatStore.conversations[index + 1]
                self.chatStore.selectConversation(next.id)
            }
        }
        
        self.chatStore.deleteConversation(conversationId)
    }
    
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
                        if self.renamingChatId == conversation.id {
                            TextField(conversation.displayName, text: self.$renamingText)
                                .focused(self.$renamingFieldFocus)
                                .textFieldStyle(PlainTextFieldStyle())
                                .lineLimit(1)
                                .onChange(of: self.renamingFieldFocus, { _, isFocused in
                                    if isFocused { return }
                                    
                                    if self.renamingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        self.renamingChatId = nil
                                        return
                                    }
                                    
                                    Task {
                                        print("Renaming to \(self.renamingText)")
                                        try await self.chatStore.updateConversationName(conversation.id, name: self.renamingText)
                                        self.renamingChatId = nil
                                    }
                                })
                                .onSubmit {
                                    if self.renamingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        self.renamingChatId = nil
                                        return
                                    }
                                    
                                    Task {
                                        print("Renaming to \(self.renamingText)")
                                        try await self.chatStore.updateConversationName(conversation.id, name: self.renamingText)
                                        self.renamingChatId = nil
                                    }
                                }
                        } else {
                            Text(conversation.displayName)
                        }
                        
                        if chatStore.loadingMap[conversation.id] == true {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .controlSize(.mini)
                                .transition(.opacity)
                                .padding(.leading, 5)
                        }
                    }
                    .onTapGesture(count: 2) {
                        if self.renamingChatId != nil { return }
                        
                        self.renamingText = ""
                        self.renamingChatId = conversation.id
                        self.renamingFieldFocus = true
                    }
                    .contextMenu {
                        Button("Delete") {
                            self.showDeleteConversationAlert = true
                        }
                        .confirmationDialog("Confirm?", isPresented: self.$showDeleteConversationAlert) {
                            Button {
                                self.deleteConversation(conversationId: conversation.id)
                            } label: {
                                Text("Delete")
                            }
                        }
                        
                        Button("Clear") {
                            self.chatStore.clearActiveConversation(conversation.id)
                        }
                        
                        Button("Rename") {
                            self.renamingText = ""
                            self.renamingChatId = conversation.id
                            self.renamingFieldFocus = true
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
                                            .transition(.opacity.combined(with: .move(edge: message.role == .assistant ? .leading : .trailing)))
                                    }
                                
                                    if let error = self.chatStore.selectedConversationError, self.chatStore.hasError {
                                        ErrorMessage(text: error.localizedDescription)
                                            .textSelection(.enabled)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                    
                                    if apiKey.isEmpty {
                                        SettingsLink {
                                            ErrorMessage(text: "No api key configured. Please double check preferences.")
                                        }
                                        .buttonStyle(.plain)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .padding(.top, 20)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 80)
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
                                    .transition(.opacity)
                                Spacer()
                            }
                            
                            ChatTextField(
                                isLoading ? "Please wait..." : self.inputPlaceholder,
                                text: $text,
                                isLoading: isLoading,
                                isEmpty: conversation.messages.isEmpty,
                                disabled: apiKey.isEmpty || isLoading
                            ) {
                                let content = self.text;
                                self.text = ""
                                self.chatStore.sendMessage(.user(conversation.id, content))
                            }
                            .disabled(apiKey.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .navigationTitle(conversation.displayName)
            } else {
                ZStack(alignment: .top) {
                    if apiKey.isEmpty {
                        SettingsLink {
                            ErrorMessage(text: "No api key configured. Click to configure")
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .buttonStyle(.plain)
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                    }
                    
                    VStack(alignment: .trailing) {
                        Spacer()
                        EmptyPlaceholder()
                        Spacer()
                        
                        ChatTextField(
                            chatStore.isLoading ? "Please wait..." : self.inputPlaceholder,
                            text: $text
                        ) {
                            let conversationId = chatStore.createConversation()
                            
                            let content = self.text
                            self.text = ""
                            chatStore.selectConversation(conversationId)
                            
                            self.chatStore.sendMessage(.user(conversationId, content))
                        }
                        .disabled(apiKey.isEmpty)
                    }
                    .padding(20)
                }
            }
        }
        ._visualEffect(material: .sidebar)
        .animation(.bouncy, value: apiKey.isEmpty)
        .animation(.bouncy, value: self.chatStore.hasError)
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(chatStore.selectedConversation?.displayName ?? "Floating AI")
                    .font(.title2)
                    .padding(.vertical ,15)
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
                    self.isShowingInfo.toggle()
                }) {
                    Label("Show Conversation Info", systemImage: "info.circle")
                }
                .keyboardShortcut("i")
                .popover(isPresented: self.$isShowingInfo, arrowEdge: .bottom) {
                    ConversationPopover(chatStore: self.chatStore)
                }
                
                Button(action: {
                    self.deleteConversation(conversationId:self.chatStore.selectedConversationID)
                }) {
                    Label("Delete Conversation", systemImage: "trash")
                }
                .keyboardShortcut(.delete)
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
                .keyboardShortcut("n")
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


import OpenAI

struct ConversationPopover: View {
    @Preference(\.model)
    var model
    
    @Preference(\.temperature)
    var temperature
    
    private(set) var chatStore: ChatStore
    
    func updateCurrentTemperature(_ temperature: Temperature) {
        guard let index = self.chatStore.selectedConversationIndex else { return }
        self.chatStore.conversations[index].temperature = temperature
    }
    
    func updateCurrentModel(_ model: Model) {
        guard let index = self.chatStore.selectedConversationIndex else { return }
        self.chatStore.conversations[index].model = model
    }
    
    var body: some View {
        VStack {
            if let conversation = chatStore.selectedConversation {
                #if DEBUG
                Form {
                    
                    HStack {
                        Text("ID:")
                        Spacer()
                        Text(conversation.id.uuidString)
                    }
                    
                    HStack {
                        Text("Name:")
                        Spacer()
                        Text(conversation.displayName)
                    }
                    
                    
                    HStack {
                        Text("Messages Count:")
                        Spacer()
                        Text(conversation.messages.count.formatted())
                    }
                    
                    HStack {
                        Text("Created At:")
                        Spacer()
                        Text(conversation.timestamp.ISO8601Format())
                    }
                }
                
                Divider()
                    .padding(.vertical, 5)
                #endif
                
                Form {
                    HStack {
                        Text("Model:")
                        Spacer()
                        AIModelPicker(model: Binding<Model>(
                            get: {
                                conversation.model ?? self.model
                            },
                            set: { model in
                                self.updateCurrentModel(model)
                            }
                        ))
                    }
                    
                    HStack {
                        Text("Creativity:")
                        Spacer()
                        AITemperaturePicker(temperature: Binding<Temperature>(
                            get: {
                                conversation.temperature ?? self.temperature
                            },
                            set: { temp in
                                self.updateCurrentTemperature(temp)
                            }
                        ))
                    }
                }
            } else {
                Form {
                    HStack {
                        Text("Model:")
                        Spacer()
                        AIModelPicker(model: self.$model)
                    }
                    
                    HStack {
                        Text("Creativity:")
                        Spacer()
                        AITemperaturePicker(temperature: self.$temperature)
                    }
                }
            }
        }
        .padding()
    }
}
