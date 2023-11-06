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
    @Environment(\.modelContext) private var modelContext
    @Query private var storedConversations: [Conversation]
    
    private var openAI: OpenAIProtocol = OpenAI(apiToken: "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")
    
    @Published
    private var currentMessage: [Conversation.ID: Message] = [:]
    
    @ObservedObject var notificationsPublisher = NotificationPublisher()
    
    @Published var model: Model = .gpt3_5Turbo_16k
    @Published var conversations: [Conversation] = []
    
    @Published var conversationErrors: [Conversation.ID: Error] = [:]
    @Published var selectedConversationID: Conversation.ID?
    @Published var drafts: [Conversation.ID: Message] = [:]
    
    @Published var loadingMap: [Conversation.ID: Bool] = [:]
    
    private var cancellables: [AnyCancellable] = []
    
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
    
    static let availableModels: [Model] = [
        .gpt3_5Turbo_16k,
        .gpt4_32k
    ]
    
    var selectedConversation: Conversation? {
        selectedConversationID.flatMap { id in
            conversations.first { $0.id == id }
        }
    }
    
    var selectedConversationPublisher: AnyPublisher<Conversation?, Never> {
        $selectedConversationID.receive(on: RunLoop.main).map { id in
            self.conversations.first(where: { $0.id == id })
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - INIT
    init() {
        self.$currentMessage
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { value in
                for item in value {
                    let message = item.value;
                    
                    guard let conversationIndex = self.conversations.firstIndex(where: { $0.id == item.key }) else {
                        return
                    }
                    
                    guard let messageIndex = self.conversations[conversationIndex].messages.firstIndex(where: { $0.id == message.id }) else {
                        self.conversations[conversationIndex].messages.append(item.value)
                        return
                    }
                    
                    self.conversations[conversationIndex].messages[messageIndex] = item.value
                }
            }
            .store(in: &self.cancellables)
    }
    
    
    // MARK: - Events
    func createConversation() -> Conversation.ID {
        let conversation = Conversation(id: .init(), [])
        conversations.append(conversation)
        return conversation.id
    }
    
    func selectConversation(_ conversationId: Conversation.ID?) {
        selectedConversationID = conversationId
    }
    
    func clearActiveConversation(_ conversationId: Conversation.ID?) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return  }
        conversations[idx].messages = []
    }
    
    @MainActor
    @discardableResult
    func updateConversationName(_ conversationId: Conversation.ID, name: String, animated: Bool? = nil) async throws -> Array<Conversation>.Index  {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return -1 }
        
        if let animated = animated, animated {
            conversations[idx].name = ""
            var index = 0
            
            while index < name.count {
                try await Task.sleep(for: .seconds(0.075))
                self.conversations[idx].name += String(name[name.index(name.startIndex, offsetBy: index)])
                index += 1
            }
        } else {
            conversations[idx].name = name
        }
        
        return idx
    }
    
    func deleteConversation(_ conversationId: Conversation.ID?) {
        conversations.removeAll(where: { $0.id == conversationId })
    }
    
    func sendMessage(
        _ message: Message
    ) {
        guard let conversationIdx = conversations.firstIndex(where: {
            $0.id == message.chat_id
        }) else { return }
        
        conversations[conversationIdx].messages.append(message)
        _completeChat_combined(conversationId: message.chat_id)
    }
    
    func askToExecuteFunction(_ instructions: String, conversationId: Conversation.ID) async throws {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let conversation = conversations[conversationIndex]
        let messages = [
            Chat(role: .system, content: self.systemPrompt)
        ] + conversation.messages.map { $0.toChat() } + [
            Chat(role: .system, content: instructions)
        ]
        
        let query = ChatQuery(
            model: self.model,
            messages: messages,
            functions: self.systemFunctions.map { $0.toChatFunctionDeclaration() }
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
                self.conversations[conversationIndex].messages.append(
                    Message.function(conversationId, "Conversation Renamed")
                )
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
    )  {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        
        let conversation = conversations[conversationIndex]
 
        self.conversationErrors[conversationId] = nil
        self.currentMessage[conversationId] = nil
        
        let messagesToAppend = message != nil ? [message!.toChat()] : []
        let messages = [
            Chat(role: .system, content: self.systemPrompt)
        ] + conversation.messages.map { $0.toChat() }.filter {
            $0.role != .function && $0.role != .system
        } + messagesToAppend
        
        let query = ChatQuery(
            model: self.model,
            messages: messages
        )
        
        self.loadingMap[conversationId] = true
        
        openAI.chatsStream(query: query)
            .receive(on: RunLoop.main)
            .sink { completion in
                switch completion {
                case .finished:
                    self.loadingMap[conversationId] = false
                    if let conversation = self.conversations.first(where: { $0.id == conversationId }) {
                        if conversation.messages.count == 2 {
                            Task {
                                try await self.askToExecuteFunction(
                                    "rename current conversation with a coincise contextual name",
                                    conversationId: conversationId
                                )
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
