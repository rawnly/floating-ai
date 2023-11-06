//
//  ChatView.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import Foundation
import SwiftUI
import OpenAI

struct ChatView: View {
    @State private var text: String = ""
    
    private let chat: Conversation
    private var onNewMessage: (_ chat_id: UUID, _ messages: [Message]) -> Void
    private var onChatRename: (_ chat_id: UUID, _ name: String) -> Void
    
    @State private var isLoading: Bool =  false
    @State private var messages: [Message]
    
    private let openAI = OpenAI(apiToken: "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")
    
    init(
        _ chat: Conversation,
        onChatRename: @escaping (_ chat_id: UUID, _ name: String) -> Void,
        _ onComplete: @escaping (_ chat_id: UUID, _ messages: [Message]) -> Void
    ) {
        self.chat = chat
        self.onNewMessage = onComplete
        self.onChatRename = onChatRename
        self.messages = chat.messages
    }
    
    var body: some View {
        VStack(alignment: self.messages.isEmpty ? .center : .trailing) {
            Text("\(self.messages.count)/\(self.chat.messages.count) messages")
            
            if self.messages.isEmpty {
                Spacer()
                Text("No messages yet.")
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .zIndex(2)
                Spacer()
            }
            
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(self.messages, id: \.id) { message in
                        ChatMessageView(message.content, style: message.role)
                    }
                }
            }
            .background(.clear)
            .cornerRadius(8)
            .zIndex(0)
            
            HStack {
                ChatTextField(
                    self.isLoading ? "Please wait..." : "Ask AI anything..",
                    text: $text,
                    isLoading: self.isLoading,
                    isEmpty: true
                ) {
                    let message = Message(
                        id: UUID().uuidString, 
                        kind: .user,
                        chat_id: chat.id,
                        self.text
                    )
                    self.text = ""
                    self.onMessageSent(message)
                }
            }
            .zIndex(1)
        }
        .padding(20)
    }

    private func onMessageSent(_ message: Message) {
        self.messages.append(message)
        
        let conversation = self.messages
            .map { msg in
                msg.toChat()
            }
        
        let system_prompt = Chat(role: .system, content: "After the first response to the user, rename a the current conversation with a simple but effective name.")
        
        let functions = [
            ChatFunctionDeclaration(
                name: "rename_conversation",
                description: "renames the current conversation",
                parameters: JSONSchema(
                    type: .object,
                    properties: [
                        "name": .init(type: .string, description: "The new name of the conversation")
                    ],
                    required: ["name"]
                )
            )
        ]
        
        let query = ChatQuery(model: .gpt3_5Turbo0613, messages: [system_prompt] + conversation, functions: functions, user: nil, stream: false)
        self.isLoading = true
        
        let aiMessage = Message(
            id: "loading",
            kind: .assistant,
            chat_id: message.chat_id,
            "Loading...."
        )
        self.messages.append(aiMessage)
        
        print("Preparing for streaming...")
        openAI.chatsStream(query: query) { result in
            switch result {
            case .success(let response):
                if let call = response.choices.first?.delta.functionCall {
                    return
                }
                
                guard let content = response.choices.first?.delta.content else { return }
                
                let targetIndex = self.messages.lastIndex { m in
                    m.id == aiMessage.id
                }
                
                guard let index = targetIndex else {
                    return
                }
                
                if content.isEmpty {
                    self.messages[index].content = content
                } else {
                    self.messages[index].content += content
                }
                
                break
                
            case .failure(let error):
                print(error.localizedDescription)
                return
            }
        } completion: { error in
            self.isLoading = false
            
            guard let error = error else {
                print("Stream completed")
                self.onNewMessage(self.chat.id, self.messages)
                return
            }
            
            print(error.localizedDescription)
        }
    }
}
