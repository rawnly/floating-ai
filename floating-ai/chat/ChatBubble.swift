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
                Markdown(message.content)
                    .markdownCodeSyntaxHighlighter(.splash(theme:.sundellsColors(withFont: .init(size: 14.0))))
                    .markdownBlockStyle(\.codeBlock, body: { configuration in
                        configuration
                            .padding()
                            .cornerRadius(8)
                            .markdownMargin(top: 5, bottom: 5)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.1))
                                    .stroke(.secondary.opacity(0.1), lineWidth: 1)
                            }
                    })
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Spacer(minLength: horizontalSpacing)
            case .user:
                Spacer(minLength: horizontalSpacing)
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            case .function:
                Spacer()
                Text(message.content)
                    .font(.footnote.monospaced())
                    .foregroundColor(Color.secondary.opacity(0.5))
                    .padding(.vertical, 20)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 5,
                            style: .continuous
                        )
                    )
                Spacer()
            default:
                EmptyView()
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        ChatBubble(
            message: Message(id: "", kind: .user, chat_id: .init(), "Hello")
        )
        
        ChatBubble(
            message: Message(id: "", kind: .function, chat_id: .init(), "conversation renamed")
        )
        
        ChatBubble(
            message: Message(id: "", kind: .assistant, chat_id: .init(), "Hello how can I assist you today?")
        )
        
        Spacer()
    }
    .padding()
}
