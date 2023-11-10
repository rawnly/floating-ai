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
    @Preference(\.apiKey)
    private var apiKey
    
    @EnvironmentObject
    var chatStore: ChatStore
    
    @State var isDroppingFile: Bool = false
    @State var isShowingInfo: Bool = false
    @State var text: String = ""
    @State var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    
    @State var notificationContent: String?
    
    @State var showClearConversationAlert: Bool = false
    @State var showDeleteConversationAlert: Bool = false
    @State var renamingChatId: Conversation.ID? = nil
    @State var renamingText: String = ""
    
    @State
    private var attachments: [Conversation.ID:[ThumbnailImage]] = [:]
    
    @FocusState var renamingFieldFocus
    
    var inputPlaceholder: String {
        if self.chatStore.isLoading {
            return "Please wait..."
        }
        
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
            conversationsList
        } detail: {
            chatDetail(conversation: chatStore.selectedConversation)
        }
        ._visualEffect(material: .sidebar)
        
        // MARK: Animations
        .animation(.bouncy, value: apiKey.isEmpty)
        .animation(.bouncy, value: self.chatStore.hasError)
        
        // MARK: Toolbar
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
                    self.isShowingInfo.toggle()
                }) {
                    Label("Show Conversation Info", systemImage: "info.circle")
                }
                .keyboardShortcut("i")
                .popover(isPresented: self.$isShowingInfo, arrowEdge: .bottom) {
                    ConversationPopover(chatStore: self.chatStore)
                }
                
                Button(action: {
                    chatStore.clearConversation(chatStore.selectedConversationID)
                }) {
                    Label("Clear Conversation", systemImage: "eraser")
                }
                .disabled(chatStore.selectedConversationID == nil)
                
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
        .onDrop(of: [.image], delegate: self)
    }
    
    
    // MARK: - Chat Detail
    @ViewBuilder
    private func chatDetail(conversation: Conversation?) -> some View {
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
            .onChange(of: conversation, { oldValue, newValue in
                if oldValue?.model != newValue?.model {
                    let model = newValue?.model ?? self.chatStore.model
                    
                    if model != .gpt4_vision_preview {
                        guard let id = newValue?.id else { return }
                        self.attachments[id] = []
                    }
                }
            })
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
                        ChatBubbles(conversation: conversation)
                            .environmentObject(self.chatStore)
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 80)
                            .id(UUID())
                    }
                }
                .zIndex(0)
                
                VStack(alignment: .trailing) {
                    if conversation?.messages.isEmpty ?? true {
                        Spacer()
                        EmptyPlaceholder()
                            .transition(.opacity)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading) {
                        if let conversation = conversation {
                            let conversationAttachments = self.attachments[conversation.id] ?? []
                            
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(conversationAttachments, id: \.id) {
                                        Thumbnail($0) { img in
                                            self.attachments[conversation.id]?
                                                .removeAll(where: { $0.id == img.id })
                                        }
                                        .transition(.opacity)
                                    }
                                }
                                .frame(height: 80)
                            }
                            .animation(.easeInOut, value: conversationAttachments.isEmpty)
                            .padding(.vertical)
                        }
                        
                        let hasFiles = conversation != nil
                            && self.attachments[conversation!.id] != nil
                            && self.attachments[conversation!.id]!.count > 0
                        
                        ChatTextField(
                            self.inputPlaceholder,
                            text: $text,
                            isLoading: self.chatStore.isLoading,
                            isEmpty: conversation?.messages.isEmpty ?? true,
                            disabled: apiKey.isEmpty || self.chatStore.isLoading,
                            isDroppingFile: self.isDroppingFile,
                            hasFiles: hasFiles
                        ) {
                            let content = self.text;
                            self.text = ""
                            
                            var conversationId: Conversation.ID
                            var attachments: [MessageAttachment] = []
                            
                            if let conversation = conversation {
                                conversationId = conversation.id
                                if let items = self.attachments[conversation.id] {
                                    attachments = items.map { .image($0.image) }
                                    self.attachments[conversation.id] = []
                                }
                            } else {
                                conversationId = chatStore.createConversation()
                                chatStore.selectConversation(conversationId)
                            }
                            
                            let message: Message = Message.user(conversationId, content, attachments: attachments)
                            
                            Task {
                                await self.chatStore.sendMessage(message)
                            }
                        }
                    }
                }
                .disabled(apiKey.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(conversation?.displayName ?? "Floating AI")
    }
    
    
    // MARK: - Conversations List
    @ViewBuilder
    private var conversationsList: some View {
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
                        HStack {
                            Text("#")
                                .foregroundStyle(Color(nsColor: .textColor).opacity(0.4))
                            
                            Text(conversation.displayName)
                                .foregroundStyle(Color(nsColor: .textColor))
                        }
                    }
                    
                    if chatStore.loadingMap[conversation.id] == true {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .controlSize(.mini)
                            .transition(.opacity)
                            .padding(.leading, 5)
                    }
                }
                .contextMenu {
                    Button("Rename") {
                        self.renamingText = ""
                        self.renamingChatId = conversation.id
                        self.renamingFieldFocus = true
                    }
                    
                    Button("Magic Rename") {
                        Task {
                            try? await self.chatStore.magicRename(conversationId: conversation.id)
                        }
                    }
                    
                    Divider()
                    
                    Button("Clear") {
                        self.chatStore.clearConversation(conversation.id)
                    }
                    
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
                }
            }
        }
        .toolbar(removing: chatStore.conversations.isEmpty ? .sidebarToggle : nil)
    }
}


// MARK: - Empty Chat Placeholder
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



import OpenAI

// MARK: - Conversation Popover Detail
struct ConversationPopover: View {
    @Environment(\.modelContext)
    var modelContext
    
    @Preference(\.model)
    var model
    
    @Preference(\.temperature)
    var temperature
    
    private(set) var chatStore: ChatStore
    
    func updateCurrentTemperature(_ temperature: Temperature) {
        guard let index = self.chatStore.selectedConversationIndex else { return }
        self.chatStore.conversations[index].temperature = temperature.rawValue
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
                        Text("Model: \(conversation.model ?? "nd")")
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
                                Temperature(rawValue: conversation.temperature ?? self.temperature.rawValue) ?? self.temperature
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


struct ChatBubbles: View {
    let conversation: Conversation?
    
    @Preference(\.apiKey)
    private var apiKey
    
    @EnvironmentObject
    private var chatStore: ChatStore
    
    var body: some View {
        VStack {
            ForEach(conversation?.visibleMessages ?? [], id: \.id) { message in
                ChatBubble(message: message)
                    .transition(.opacity.combined(with: .move(edge: message.role == .assistant ? .leading : .trailing)))
            }
            
            if let error = self.chatStore.selectedConversationError, self.chatStore.hasError {
                ErrorMessage(text: error.localizedDescription)
                    .textSelection(.enabled)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .contextMenu {
                        Button("Dismiss") {
                            self.chatStore.clearErrors(conversation?.id)
                        }
                    }
            }
            
            if apiKey.isEmpty {
                SettingsLink {
                    ErrorMessage(text: "No api key configured. Please double check preferences.")
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}


extension ChatsList: DropDelegate {
    private func isImageDuplicate(image: ThumbnailImage) -> Bool {
        guard let conversationId = self.chatStore.selectedConversationID else { return false }
        guard let images = self.attachments[conversationId] else { return false }
        
        return images.contains(where: { $0.id == image.id })
    }
    
    func dropEntered(info: DropInfo) {
        self.isDroppingFile = true
    }
    
    func dropExited(info: DropInfo) {
        self.isDroppingFile = false
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        guard let conversation = self.chatStore.selectedConversation else { return false }
        
        let model = conversation.model ?? self.chatStore.model
        
        if model == .gpt4_vision_preview {
            return info.hasItemsConforming(to: [.image])
        }
        
        return false
    }
    
    @MainActor
    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        
        for provider in providers {
            let _ = provider.loadDataRepresentation(for: .fileURL, completionHandler: { data, err in
                if let err = err {
                    print(err.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    print("NO DATA")
                    return
                }
                
                
                
                DispatchQueue.main.async {
                    guard let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    
                    do {
                        let data = try Data(contentsOf: url);
                        
                        guard let image = NSImage(data: data) else {
                            print("onDrop: noImage")
                            return
                        }
                        
                        guard let image = NSImage(data: data) else {
                            print("onDrop: noImage")
                            return
                        }
                        
                        guard let conversation = self.chatStore.selectedConversation else {
                            print("onDrop: no conversation")
                            return
                        }
                        
                        let element = ThumbnailImage(image, id: url.path())
                        
                        if self.attachments.keys.first(where: { $0 == conversation.id }) != nil {
                            if let attachments = self.attachments[conversation.id] {
                                if attachments.contains(where: { $0.id == element.id }) {
                                    return
                                }
                            }
                            
                            self.attachments[conversation.id]?.append(element)
                        } else {
                            self.attachments[conversation.id] = [element]
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                
            })
        }
        
        
        return true
    }
}
