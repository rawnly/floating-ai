//
//  Item.swift
//  floating-ai
//
//  Created by Federico Vitale on 03/11/23.
//

import Foundation
import SwiftData

@Model
final class Conversation {
    typealias ID = UUID
    
    var timestamp: Date
    var id: ID
    var name: String?
    var messages: [Message]
    
    
    init(id: UUID, _ messages: [Message]?) {
        self.timestamp = Date.now
        self.id = id
        self.messages = messages ?? []
    }
    
    convenience init() {
        self.init(id: .init(), nil)
    }
}
