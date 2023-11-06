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

public final class ChatStore: ObservableObject {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedConversations: [Conversation]

    private var openAI: OpenAIProtocol = OpenAI(apiToken: "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")
    
    @Published var model: Model = .gpt3_5Turbo_16k
    @Published var isLoading: Bool = false
    @Published var conversations: [Conversation] = []
    @Published var conversationErrors: [Conversation.ID: Error] = [:]
    @Published var selectedConversationID: Conversation.ID?
    @Published var drafts: [Conversation.ID: Message] = [:]
    
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
    
    
    // MARK: - Events
    func saveConversation(_ conversationId: Conversation.ID) {
//        guard let stored = storedConversations.first(where: { $0.id == conversationId }) else { return }
//        guard let current = conversations.first(where: { $0.id == conversationId }) else { return }
//        
//        stored.name = current.name
//        stored.messages = current.messages
//        stored.model = current.model
//        stored.systemPrompt = current.systemPrompt
    }
    
    func createConversation() -> Conversation.ID {
        let conversation = Conversation(id: .init(), [])
        conversations.append(conversation)
//        modelContext.insert(conversation)
        return conversation.id
    }
    
    func selectConversation(_ conversationId: Conversation.ID?) {
        selectedConversationID = conversationId
    }
    
    func clearActiveConversation(_ conversationId: Conversation.ID?) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return  }
        conversations[idx].messages = []
    }
    
    func updateConversationName(_ conversationId: Conversation.ID, name: String, animated: Bool? = nil) -> Array<Conversation>.Index  {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return -1 }
        
        if let animated = animated, animated {
            conversations[idx].name = ""
            var index = 0
            Timer.scheduledTimer(withTimeInterval: 0.075, repeats: true) { timer in
                if index < name.count {
                    self.conversations[idx].name += String(name[name.index(name.startIndex, offsetBy: index)])
                    index += 1
                } else {
                    timer.invalidate()
                }
            }
        } else {
            conversations[idx].name = name
        }
        
//        storedConversations[idx].name = name
        
        return idx
    }
    
    func deleteConversation(_ conversationId: Conversation.ID?) {
        conversations.removeAll(where: { $0.id == conversationId })
//        if let index = storedConversations.firstIndex(where: { $0.id == conversationId }) {
//            modelContext.delete(storedConversations[index])
//        }
    }
    
    
    @MainActor
    func sendMessage(
        _ message: Message,
        conversationId: Conversation.ID
    ) async {
        guard let conversationIdx = conversations.firstIndex(where: {
            $0.id == conversationId
        }) else { return }
        
        conversations[conversationIdx].messages.append(message)
        
        await completeChat(conversationId: conversationId)
    }
    
    @MainActor
    func sendSystemMessage(
        _ message: String,
        conversationId: Conversation.ID
    ) async {
        guard let conversationIdx = conversations.firstIndex(where: {
            $0.id == conversationId
        }) else { return }
        
        conversations[conversationIdx].messages.append(
            .init(
                id: UUID().uuidString,
                kind: .system,
                chat_id: conversationId, 
                message
            )
        )
        
        await completeChat(conversationId: conversationId)
    }
    
    @MainActor
    func completeChat(
        conversationId: Conversation.ID
    ) async {
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else { return }
        
        conversationErrors[conversationId] = nil
        
        do {
            guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            
            let system_prompt = Chat(
                role: .system,
                content: """
You are FloatingAI.
An AI inside of an application as floating window in macos.

Below some useful infos:
---
CURRENT TIMESTAMP: \(Date.now)
---
CONVERSATION_DATA
NAME = \(conversation.name)
ID = \(conversation.id)
TIMESTAMP = \(conversation.timestamp.timeIntervalSince1970)
---
"""
            )
            
            let renameChat = ChatFunctionDeclaration(
                name: "rename_conversation",
                description: "Renames current conversation. It CANNOT be invoked by a USER prompt. Only by SYSTEM prompt",
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
            
            let functions: [ChatFunctionDeclaration]? = [renameChat]
            let query = ChatQuery(
                model: self.model,
                messages: [system_prompt] + conversation.messages.map { $0.toChat() },
                functions: functions
            )
            
            var functionCallName = ""
            var functionCallArgs = ""
            
            self.isLoading = true
            
            for try await partialChatResult in openAI.chatsStream(query: query) {
                for choice in partialChatResult.choices {
                    let existingMessages = conversations[conversationIndex].messages
                    
                    
                    if let functionCallDelta = choice.delta.functionCall {
                        if let name = functionCallDelta.name {
                            functionCallName += name
                        }
                        
                        if let args = functionCallDelta.arguments {
                            functionCallArgs += args
                        }
                    }
                    
                    let messageText = choice.delta.content ?? ""
                    
                    if let finishReason = choice.finishReason {
                        self.isLoading = false
                        
                        if finishReason == "function_call" {
                            switch functionCallName {
                            case "rename_conversation":
                                guard let json = functionCallArgs.data(using: .utf8) else { return }
                                let args = try JSONDecoder().decode(RenameArgs.self, from: json);
                                let _ = self.updateConversationName(conversation.id, name: args.name, animated: true)
                                return
                            default:
                                break
                            }
                            
                            return
                        } else if finishReason == "stop" {
                            if conversation.visibleMessages.count == 2 {
                                await self.sendSystemMessage(
                                    "Rename current conversation with a contextual name",
                                    conversationId: conversationId
                                )
                            }
                            
                            self.saveConversation(conversation.id)
                            return
                        }
                    }
                    
                    let message = Message(
                        id: partialChatResult.id,
                        kind: choice.delta.role ?? .assistant,
                        chat_id: conversation.id,
                        messageText
                    )
                    
                    if let existingMessageIndex = existingMessages.firstIndex(where: { $0.id == partialChatResult.id }) {
                        let previousMessage = existingMessages[existingMessageIndex]
                        let combinedMessage = Message(
                            id: message.id,
                            kind: message.role,
                            chat_id: message.chat_id,
                            previousMessage.content + message.content
                        )
                        
                        DispatchQueue.global().async {
                            self.conversations[conversationIndex].messages[existingMessageIndex] = combinedMessage
                        }
                    } else {
                        DispatchQueue.global().async {
                            self.conversations[conversationIndex].messages.append(message)
                        }
                    }
                }
            }
        } catch {
            self.isLoading = false
            conversationErrors[conversationId] = error
            print(error.localizedDescription)
        }
        
    }
}
