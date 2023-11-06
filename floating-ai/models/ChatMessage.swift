//
//  ChatMessage.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import SwiftData
import Foundation
import OpenAI

struct Message: Identifiable, Equatable {
    var id: String
    var chat_id: UUID
    var timestamp: Date
    var content: String
    var role: Chat.Role
    
    init(id: String, kind: Chat.Role, chat_id: UUID, _ content: String) {
        self.id = id;
        self.timestamp = Date.now
        self.content = content
        self.chat_id = chat_id
        self.role = kind
    }
}

extension Message {
    static func +(lhs: Message, rhs: Message) -> Message {
        return Message(
            id: rhs.id,
            kind: rhs.role,
            chat_id: rhs.chat_id,
            lhs.content + rhs.content
        )
    }
}

extension Message {
    func toChat() -> Chat {
        Chat(role: self.role, content: self.content)
    }
    
    static func system(_ conversationId: Conversation.ID, _ content: String) -> Self {
        return Message(
            id: UUID().uuidString,
            kind: .system,
            chat_id: conversationId,
            content
        )
    }
    
    static func user(_ conversationId: Conversation.ID, _ content: String) -> Self {
        return Message(
            id: UUID().uuidString,
            kind: .user,
            chat_id: conversationId,
            content
        )
    }
    
    static func function(_ conversationId: Conversation.ID, _ content: String) -> Self {
        return Message(
            id: UUID().uuidString,
            kind: .function,
            chat_id: conversationId,
            content
        )
    }
}

extension Message: Codable {
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case chat_id = "chat_id"
        case timestamp = "timestamp"
        case content = "content"
        case role = "kind"
    }
}
    
