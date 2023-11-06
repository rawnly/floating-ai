//
//  Item.swift
//  floating-ai
//
//  Created by Federico Vitale on 03/11/23.
//

import Foundation
import OpenAI
import SwiftData

@Model
final class Conversation {
    typealias ID = UUID
    
    var timestamp: Date
    var id: ID
    var name: String
    var messages: [Message]
    var systemPrompt: String?
    var model: Model?
    
    var visibleMessages: [Message] {
        get {
            self.messages.filter {
                !$0.content.isEmpty
            }
        }
    }
    
    init(id: UUID, _ messages: [Message]?) {
        self.timestamp = Date.now
        self.id = id
        self.messages = messages ?? []
        self.name = "New Conversation"
    }
    
    convenience init() {
        self.init(id: .init(), nil)
    }
}
