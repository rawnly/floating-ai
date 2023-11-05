//
//  ChatStore.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import Foundation
import Combine
import OpenAI

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
    
    func updateConversationName(_ conversationId: Conversation.ID, name: String) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[idx].name = name
    }
    
    func deleteConversation(_ conversationId: Conversation.ID) {
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
    func completeChat(
        conversationId: Conversation.ID
    ) async {
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else { return }
        
        conversationErrors[conversationId] = nil
        
        do {
            guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            
            let functions: [ChatFunctionDeclaration]? = nil
            let query = ChatQuery(
                model: .gpt3_5Turbo0613,
                messages: conversation.messages.map { $0.toChat() },
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
                    
                    var messageText = choice.delta.content ?? ""
                    if let finishReason = choice.finishReason, finishReason == "function_call" {
                        messageText += "Function Call: name=\(functionCallName) arguments=\(functionCallArgs)"
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
