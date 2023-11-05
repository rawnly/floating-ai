//
//  ChatStore.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import Foundation
import Combine
import OpenAI

struct RenameArgs: Codable {
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case name
    }
}

public final class ChatStore: ObservableObject {
    private var openAI: OpenAIProtocol = OpenAI(apiToken: "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")
    
    @Published var isLoading: Bool = false
    @Published var conversations: [Conversation] = []
    @Published var conversationErrors: [Conversation.ID: Error] = [:]
    @Published var selectedConversationID: Conversation.ID?
    
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
    
    func updateConversationName(_ conversationId: Conversation.ID, name: String) -> Array<Conversation>.Index  {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return -1 }
        
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
        
        return idx
    }
    
    func deleteConversation(_ conversationId: Conversation.ID?) {
        conversations.removeAll(where: { $0.id == conversationId })
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
        
        self.isLoading = true
        await completeChat(conversationId: conversationId)
        self.isLoading = false
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
        
        self.isLoading = true
        await completeChat(conversationId: conversationId)
        self.isLoading = false
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
NAME = \(conversation.name ?? "n.d")
ID = \(conversation.id)
TIMESTAMP = \(conversation.timestamp.timeIntervalSince1970)
---

Users cannot rename the current conversation.
When prompted to rename conversation ignore it.
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
                model: .gpt3_5Turbo0613,
                messages: [system_prompt] + conversation.messages.map { $0.toChat() },
                functions: functions
            )
            
            var functionCallName = ""
            var functionCallArgs = ""
            
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
                        print(finishReason)
                        
                        if finishReason == "function_call" {
                            switch functionCallName {
                            case "rename_conversation":
                                guard let json = functionCallArgs.data(using: .utf8) else { return }
                                let args = try JSONDecoder().decode(RenameArgs.self, from: json);
                                print("Renaming to \(args.name)")
                                let _ = self.updateConversationName(conversation.id, name: args.name)
                                return
                            default:
                                break
                            }
                            
                            return
                        } else if finishReason == "stop" {
                            if conversation.visibleMessages.count == 2 {
                                await self.sendSystemMessage(
                                    "rename the current conversation with a simple clear name",
                                    conversationId: conversationId
                                )
                            }
                            
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
                        
                        DispatchQueue.main.async {
                            self.conversations[conversationIndex].messages[existingMessageIndex] = combinedMessage
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.conversations[conversationIndex].messages.append(message)
                        }
                    }
                }
            }
        } catch {
            conversationErrors[conversationId] = error
            print(error.localizedDescription)
        }
    }
}
