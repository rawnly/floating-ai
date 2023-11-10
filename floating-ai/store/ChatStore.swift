//
//  ChatStore.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import Foundation
import Combine
import OpenAI
import SwiftUI
import SwiftData

struct RenameArgs: Codable {
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case name
    }
}

enum FunctionCalls: String {
    case RenameConversation = "rename_conversation"
}

struct FunctionDeclaration {
    enum Name: String {
        case Rename = "rename_conversation"
    }
    
    let name: Name
    let description: String
    let parameters: JSONSchema
    
    func toChatFunctionDeclaration() -> ChatFunctionDeclaration {
        return ChatFunctionDeclaration(
            name: self.name.rawValue,
            description: self.description,
            parameters: self.parameters
        )
    }
}

@MainActor
public final class ChatStore: ObservableObject {
    var cancellables: [AnyCancellable] = []
    
    @Preference(\.apiKey)
    private(set) var apiKey
    
    @Preference(\.model)
    private(set) var model
    
    @Preference(\.temperature)
    private var temperature
    
    private var openAI: OpenAIProtocol {
        return OpenAI(apiToken: apiKey)
    }
    
    @Published
    private var currentMessage: [Conversation.ID: Message] = [:]
    
    @ObservedObject
    var notificationsPublisher = NotificationPublisher()
    
    @Published var conversations: [Conversation] = [] {
        didSet {
            print("udpated")
        }
    }
    
    @Published 
    private var conversationErrors: [Conversation.ID: Error] = [:]
    
    @Published var selectedConversationID: Conversation.ID? {
        willSet {
            if let id = selectedConversationID {
                self.saveCurrentConversation(id)
            }
        }
    }
    
    @Published 
    var loadingMap: [Conversation.ID: Bool] = [:]
    
    
    private let systemPrompt: String = """
You are Floating AI, a large language model. Answer as coincisely as possible. Respond with markdown syntax.
Current date (ISO8601): \(Date.now.ISO8601Format())
"""
    private let systemFunctions: [FunctionDeclaration] = [
        FunctionDeclaration(
            name: .Rename,
            description: "Renames current conversation",
            parameters: JSONSchema(
                type: .object,
                properties: [
                    "name": .init(
                        type: .string,
                        description: "The new name of the conversation"
                    )
                ],
                required: ["name"]
            )
        )
    ]
    
    var isLoading: Bool {
        guard let id = selectedConversationID else { return false }
        
        return loadingMap[id] ?? false
    }
    
    public static let availableModels: [Model] = [
        .gpt3_5Turbo_1106,
        .gpt4_1106_preview,
        .gpt4_vision_preview
    ]
    
    var selectedConversationError: Error? {
        guard let id = self.selectedConversationID else { return nil }
        return self.conversationErrors[id]
    }
    
    var selectedConversation: Conversation? {
        selectedConversationID.flatMap { id in
            conversations.first { $0.id == id }
        }
    }
    
    var selectedConversationIndex: Array<Conversation>.Index? {
        selectedConversationID.flatMap { id in
            conversations.firstIndex { $0.id == id }
        }
    }
    
    var selectedConversationPublisher: AnyPublisher<Conversation?, Never> {
        $selectedConversationID.receive(on: RunLoop.main).map { id in
            self.conversations.first(where: { $0.id == id })
        }
        .eraseToAnyPublisher()
    }
    
    var hasError: Bool {
        return selectedConversationError != nil
    }
    
    // MARK: - INIT
    init() {
        self.$currentMessage
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(150), scheduler: DispatchQueue.main, latest: true)
            .sink { value in
                for item in value {
                    let message = item.value;
                    
                    guard let conversationIndex = self.conversations.firstIndex(where: { $0.id == item.key }) else {
                        return
                    }
                    
                    guard let messageIndex = self.conversations[conversationIndex].messages.firstIndex(where: { $0.id == message.id }) else {
                        self.conversations[conversationIndex].messages.append(item.value)
                        self.objectWillChange.send()
                        return
                    }
                    
                    self.conversations[conversationIndex].messages[messageIndex] = item.value
                    self.objectWillChange.send()
                }
            }
            .store(in: &self.cancellables)
    }
    
    // MARK: - SwiftData
    func saveCurrentConversation(_ conversationId: Conversation.ID) {
//        guard let index = self.conversations.firstIndex(where: { $0.id == conversationId }) else { return }
//        let conversation = self.conversations[index]
//        
//        guard let storedIndex = self.storedConversations.firstIndex(where: { $0.id == conversationId }) else {
////            self.modelContext.insert(conversation)
//            return
//        }
//        
//        self.storedConversations[storedIndex].name = conversation.name
//        self.storedConversations[storedIndex].messages = conversation.messages
//        self.storedConversations[storedIndex].model = conversation.model
//        self.storedConversations[storedIndex].temperature = conversation.temperature
    }
    
    func load() {
        DispatchQueue.main.async {
//            self.conversations = self.storedConversations
        }
    }
    
    
    
    // MARK: - Events
    func magicRename(conversationId: Conversation.ID) async throws {
        try await self.askToExecuteFunction("""
Summarize the chat into a short title following the instructions:
1. Consider the topic/theme of the conversation
2. Incorporate a descriptive adjective that captures the tone or nature of the interactions
3. Include an element that reflects the context or relationship
4. 9 words or less on a single line
5. Do not include any of the chat instructions or prompts in the summary.
6. Do not prefix with "title" or "example"
7. Do not provide a word count or add quotation marks
""", conversationId: conversationId)
    }
    
    @discardableResult
    func createConversation() -> Conversation.ID {
        let conversation = Conversation(model: self.model, temperature: self.temperature)
        self.conversations.append(conversation)
        return conversation.id
    }
    
    func selectConversation(_ conversationId: Conversation.ID?) {
        self.selectedConversationID = conversationId
    }
    
    func clearErrors(_ conversationId: Conversation.ID?) {
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else {
            print("clearActiveConversation(\(conversationId): INVALID ID")
            return
        }
        
        self.conversationErrors[conversation.id] = nil
        self.objectWillChange.send()
    }
    
    func clearConversation(_ conversationId: Conversation.ID?) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else {
            print("clearActiveConversation(\(conversationId): INVALID ID")
            return
        }
        
        let conversation = conversations[idx]
        
        self.conversations[idx].messages = []
        self.conversationErrors[conversation.id] = nil
        self.currentMessage[conversation.id] = nil
        
        self.cancellables.first?.cancel()
        self.loadingMap[conversation.id] = false
        
        self.objectWillChange.send()
    }
    
    @MainActor
    @discardableResult
    func updateConversationName(_ conversationId: Conversation.ID, name: String, animated: Bool? = nil) async throws -> Array<Conversation>.Index  {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return -1
        }
        
        if let animated = animated, animated {
            conversations[idx].name = ""
            var index = 0
            
            while index < name.count {
                try await Task.sleep(for: .seconds(0.075))
                
                let partialName = String(name[name.index(name.startIndex, offsetBy: index)])
                
                if self.conversations[idx].name == nil {
                    self.conversations[idx].name = partialName
                } else {
                    self.conversations[idx].name! += String(name[name.index(name.startIndex, offsetBy: index)])
                }
                
                self.objectWillChange.send()
                index += 1
            }
        } else {
            conversations[idx].name = name
            self.objectWillChange.send()
        }
        
        return idx
    }
    
    func deleteConversation(_ conversationId: Conversation.ID?) {
        conversations.removeAll(where: { $0.id == conversationId })
        
        if let conversationId = conversationId {
            self.conversationErrors.removeValue(forKey: conversationId)
            self.currentMessage.removeValue(forKey: conversationId)
            self.loadingMap.removeValue(forKey: conversationId)
        }
    }
    
    @MainActor
    func sendMessage(
        _ message: Message
    ) async {
        guard let conversationIdx = conversations.firstIndex(where: {
            $0.id == message.conversationId
        }) else {
            print("sendMessage(\(message.content)): INVALID CHAT_ID")
            return
        }
        
        conversations[conversationIdx].messages.append(message)
        self.objectWillChange.send()
        
        await _completeChat_combined(conversationId: message.conversationId)
    }
    
    @MainActor
    func askToExecuteFunction(_ instructions: String, conversationId: Conversation.ID) async throws {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let conversation = conversations[conversationIndex]
        let messages = [
            Chat(role: .system, content: self.systemPrompt)
        ] + conversation.messages
        // skip executions
            .filter { $0.role != .function }
        // we skip images since gpt4-vision is the only model that supports that message format
            .map { $0.toChat(skipAttachments: true) } + [
            Chat(role: .system, content: instructions)
        ]
        
        var model = self.model
        // gpt4_vision_preview does not support function/tools calling
        // we have to fallback on gpt4
        if model == .gpt4_vision_preview {
            model = .gpt4
        }
        
        let query = ChatQuery(
            model: model,
            messages: messages,
            functions: self.systemFunctions.map { $0.toChatFunctionDeclaration() },
            temperature: self.temperature.rawValue
        )
        
        
        let chatResult = try await openAI.chats(query: query)
        
        for choice in chatResult.choices {
            guard let finishReason = choice.finishReason else {
                return
            }
            
            if finishReason != "function_call" { return }
            
            guard let call = choice.message.functionCall else { return }
            guard let arguments = call.arguments else { return }
            guard let name = FunctionDeclaration.Name(rawValue: call.name ?? "") else { return }
            
            guard let json = arguments.data(using: .utf8) else { return }
            
            switch name {
            case .Rename:
                let args = try JSONDecoder().decode(RenameArgs.self, from: json);
                try await self.updateConversationName(conversation.id, name: args.name, animated: true)
//                self.conversations[conversationIndex].messages.append(
//                    Message.function(conversationId, "Conversation Renamed")
//                )
                self.objectWillChange.send()
                break
            }
        }
    }
    
    @MainActor
    private func _isLoading(id conversationId: Conversation.ID) -> Bool {
        self.loadingMap[conversationId] ?? false
    }
    
    @MainActor
    func _completeChat_combined(
        conversationId: Conversation.ID,
        message: Message? = nil
    ) async {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        
        let conversation = conversations[conversationIndex]
 
        self.conversationErrors[conversationId] = nil
        self.currentMessage[conversationId] = nil
        
        
        let messagesToAppend = message != nil ? [message!.toChat()] : []
        var allMessages = [
            Chat(role: .system, content: self.systemPrompt)
        ]
        
        self.loadingMap[conversationId] = true
        
        let messagesWithMedia = conversation.messages.map {
            $0.toChat()
        }
//        let messagesWithMedia = try? await conversation.messages.asyncMap {
//            try await $0.toChatAsync()
//        }
        
//        if let medias = messagesWithMedia {
            allMessages.append(contentsOf: messagesWithMedia.filter {
                $0.role != .function && $0.role != .system
            })
//        }
        
        allMessages.append(contentsOf: messagesToAppend)
        
        let model = conversation.model ?? self.model
        let query = ChatQuery(
            model: conversation.model ?? self.model,
            messages: allMessages,
            temperature: conversation.temperature ?? self.temperature.rawValue,
            maxTokens: model == .gpt4_vision_preview ? 300 : nil
        )
        
        openAI.chatsStream(query: query)
            .receive(on: RunLoop.main)
            .sink { completion in
                switch completion {
                case .finished:
                    self.loadingMap[conversationId] = false
                    if let conversation = self.conversations.first(where: { $0.id == conversationId }) {
                        if conversation.messages.count == 2 && conversation.canAIRename {
                            Task {
                                try await self.magicRename(conversationId: conversation.id)
                            }
                        }
                    }
                    
                    break
                case .failure(let error):
                    print(error.localizedDescription)
                    self.conversationErrors[conversationId] = error
                    break
                }
            } receiveValue: { result in
                switch result {
                case .success(let partialResult):
                    for choice in partialResult.choices {
                        let partialMessage = Message(
                            id: partialResult.id,
                            kind: .assistant,
                            chat_id: conversationId,
                            choice.delta.content ?? ""
                        )
                        
                        guard let message = self.currentMessage[conversationId] else {
                            self.currentMessage[conversationId] = partialMessage
                            continue
                        }
                        
                        let combinedMessage = message + partialMessage
                        self.currentMessage[conversationId] = combinedMessage
                    }
                    
                    break
                case .failure(let error):
                    print(error.localizedDescription)
                    self.conversationErrors[conversationId] = error
                    break
                }
            }
            .store(in: &self.cancellables)
    }
}

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()
        
        for el in self {
            try await values.append(transform(el))
        }
        
        return values
    }
}
