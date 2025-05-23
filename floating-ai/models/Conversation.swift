//
//  Item.swift
//  floating-ai
//
//  Created by Federico Vitale on 03/11/23.
//

import Foundation
import OpenAI
import SwiftData

enum Temperature: Double, CaseIterable {
    case none = 0.0
    case low = 0.5
    case medium = 1
    case high = 1.5
    case veryHigh = 2
    
    var stringValue: String {
        switch self {
        case .none:
            return "None"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .veryHigh:
            return "Very High"
        }
    }
}

final class Conversation: Identifiable {
    var id: UUID
    var timestamp: Date
    var messages: [Message]
    var systemPrompt: String?
    
    var name: String?
    var temperature: Double?
    var model: Model?
    
    var canAIRename: Bool {
        return self.name == nil && Preferences.standard.autoRenameChat
    }
    
    var displayName: String {
        guard let name = self.name else {
            return "New Conversation"
        }
        
        return name
    }
    
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
        self.name = nil
    }
    
    init(model: Model, temperature: Temperature?=nil) {
        self.timestamp = Date.now
        self.id = UUID()
        self.messages = []
        self.name = nil
        self.model = model
        self.temperature = temperature?.rawValue
    }
    
    convenience init() {
        self.init(id: .init(), nil)
    }
}

extension Conversation:Equatable {
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.name == rhs.name && lhs.id == rhs.id && lhs.model == rhs.model && lhs.temperature == rhs.temperature
    }
}
