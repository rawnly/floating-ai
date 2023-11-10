//
//  ChatMessage.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import SwiftData
import Foundation
import OpenAI
import Cocoa
import Alamofire


enum MessageAttachment: Equatable {
   case image(NSImage)
}

final class Message: Identifiable, Equatable {
    private let cloudinaryApi = CloudinaryAPI(cloud_id: "dpcawz5hj", apiKey: "494171277924628", apiSecret: nil)
    
    var id: String
    var conversationId: UUID
    var timestamp: Date
    var content: String
    var attachments: [MessageAttachment]
    var role: Chat.Role
    
    init(id: String, kind: Chat.Role, chat_id: UUID, _ content: String) {
        self.id = id;
        self.timestamp = Date.now
        self.content = content
        self.conversationId = chat_id
        self.role = kind
        self.attachments = []
    }
    
    init(id: String, role: Chat.Role, conversationId: UUID, attachments: [MessageAttachment], _ content: String) {
        self.id = id;
        self.timestamp = Date.now
        self.content = content
        self.conversationId = conversationId
        self.role = role
        self.attachments = attachments
    }
}

extension Message {
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id && rhs.role == lhs.role && rhs.content == lhs.content && rhs.attachments == lhs.attachments
    }
    
    static func +(lhs: Message, rhs: Message) -> Message {
        return Message(
            id: rhs.id,
            role: rhs.role,
            conversationId: rhs.conversationId,
            attachments: lhs.attachments + rhs.attachments,
            lhs.content + rhs.content
        )
    }
}

extension Message {
    func toChat(skipAttachments: Bool = false) -> Chat {
        // NOTE: we skip upload now
        // let's try via base64 encoded images
        // @see https://platform.openai.com/docs/api-reference/chat/create#:~:text=Either%20a%20URL%20of%20the%20image%20or%20the%20base64%20encoded%20image%20data.
        let images = self.attachments.compactMap {
            switch $0 {
            case .image(let nsimage):
                return nsimage.base64
            }
        }
        .map { ChatContent.imageUrl($0) }
        
        var contents: [ChatContent] = [
            .text(self.content)
        ]
        
        if !skipAttachments {
            contents.append(contentsOf: images)
        }
        
        return Chat(role: self.role, contents: .object(contents))
    }
    
    func toChatAsync() async throws -> Chat {
        var attachments: [ChatContent] = []
        let images = self.attachments.compactMap {
            switch $0 {
            case .image(let nsimage):
                return nsimage
            }
        }
        
        for image in images {
            guard let data = image.tiffRepresentation else {
                continue
            }
            
            let cloudinaryItem = try await self.cloudinaryApi.upload(data: data)
            attachments.append(.imageUrl(cloudinaryItem.url))
        }
        
        return Chat(role: self.role, contents: .object([
            .text(self.content),
        ] + attachments))
    }
    
    static func system(_ conversationId: Conversation.ID, _ content: String) -> Message {
        return Message(
            id: UUID().uuidString,
            role: .system,
            conversationId: conversationId,
            attachments: [],
            content
        )
    }
    
    static func user(_ conversationId: Conversation.ID, _ content: String, attachments: [MessageAttachment] = []) -> Message {
        return Message(
            id: UUID().uuidString,
            role: .user,
            conversationId: conversationId,
            attachments: attachments,
            content
        )
    }
    
    static func function(_ conversationId: Conversation.ID, _ content: String) -> Message {
        return Message(
            id: UUID().uuidString,
            role: .function,
            conversationId: conversationId,
            attachments: [],
            content
        )
    }
}

extension NSImage {
    var base64: String? {
        guard let imageData = self.tiffRepresentation else {
            return nil
        }
        
        let bitmapRep = NSBitmapImageRep(data: imageData)
        
        guard let pngData = bitmapRep?.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let uri = pngData.base64EncodedString(options: [])
        
        return "data:image/png;base64,\(uri)"
    }
}
