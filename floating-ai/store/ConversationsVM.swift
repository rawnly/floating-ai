//
//  ChatVM.swift
//  Floating AI
//
//  Created by Federico Vitale on 08/11/23.
//

import Foundation
import Combine

final class ConversationsVM: ObservableObject {
    @Preference(\.apiKey)
    private var apiKey
    
    @Published
    var conversations: [Conversation] = []
    
    @Published
    fileprivate var currentMessage: [Conversation.ID:Message] = [:]
    
    @Published
    var selectedConversationID: Conversation.ID? = nil
    
    
    var selectedConversationIndex: Array<Conversation>.Index? {
        guard let id = self.selectedConversationID else {
            return nil
        }
        
        return self.conversations.firstIndex(where: { $0.id == id })
    }
    
    var selectedConversationPublisher: AnyPublisher<Conversation?, Never> {
        $selectedConversationID.receive(on: RunLoop.main).map { id in
            self.conversations.first(where: { $0.id == id })
        }
        .eraseToAnyPublisher()
    }
    
    var selectedConversation: Conversation? {
        guard let id = self.selectedConversationID else {
            return nil
        }
        
        return self.conversations.first(where: { $0.id == id })
    }
}

// MARK: - Operations
extension ConversationsVM {
    @discardableResult
    func newConversation(_ name: String?=nil) -> Conversation.ID {
        let conversation = Conversation(
            model: Preferences.standard.model,
            temperature: Preferences.standard.temperature
        )
        
        if let name = name {
            conversation.name = name
        }
        
        self.conversations.append(conversation)
        
        return conversation.id
    }
    
    private func isSelected(_ conversationID: Conversation.ID) -> Bool {
        self.selectedConversationID == conversationID
    }
    
    func deleteConversation(_ conversationId: Conversation.ID?) {
        self.conversations.removeAll(where: { $0.id == conversationId })
    }
    
    func clearConversation(_ conversationId: Conversation.ID?) {
        guard let index = self.conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        self.conversations[index].messages = []
    }
    
    func renameConversation(_ conversationId: Conversation.ID?, name: String? = nil) {
        guard let index = self.conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        self.conversations[index].name = name
    }
    
    func sendMessage(to conversationId: Conversation.ID, content: String) {
        guard let index = self.conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let message = Message.user(conversationId, content)
        self.conversations[index].messages.append(message)
    }
}

// MARK: - Utilities
