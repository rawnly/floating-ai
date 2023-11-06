//
//  ChatBubble.swift
//  Floating AI
//
//  Created by Federico Vitale on 06/11/23.
//

import SwiftUI
import MarkdownUI

struct ChatBubble: View {
    let message: Message
    
    private let horizontalSpacing: CGFloat = 36
    private let cornerRadius: CGFloat = 8;
    private var assistantColor: Color {
        Color(light: .black, dark: .white)
    };
    
    private var assistantForeground: Color {
        Color(light: .white, dark: .black)
    }
    
    private let userColor = Color.accentColor.opacity(0.9);
    
    
    var body: some View {
        HStack {
            switch message.role {
            case .assistant:
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(assistantColor)
                    .foregroundStyle(assistantForeground)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: cornerRadius,
                            style: .continuous
                        )
                    )
                Spacer(minLength: horizontalSpacing)
//                Button(action: {}) {
//                    Image(systemName: "square.and.arrow.up")
//                }
//                .buttonStyle(.borderedProminent)
            case .user:
                Spacer(minLength: horizontalSpacing)
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .border(.white.opacity(0.1))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: cornerRadius,
                            style: .continuous
                        )
                    )
            default:
                Spacer()
                Text(message.content)
                    .font(.footnote.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundColor(Color.secondary.opacity(0.5))
                    .background(assistantColor.opacity(0.05))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 5,
                            style: .continuous
                        )
                    )
                Spacer()
            }
        }
    }
}

#Preview {
    VStack {
        
        ChatBubble(
            message: Message(id: "", kind: .user, chat_id: .init(), "Hello")
        )
        
        ChatBubble(
            message: Message(id: "", kind: .system, chat_id: .init(), "Event")
        )
        
        ChatBubble(
            message: Message(id: "", kind: .assistant, chat_id: .init(), "Hello how can I assist you today?")
        )
    }
}
