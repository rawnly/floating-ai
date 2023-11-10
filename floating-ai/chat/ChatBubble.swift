//
//  ChatBubble.swift
//  Floating AI
//
//  Created by Federico Vitale on 06/11/23.
//

import SwiftUI
import MarkdownUI
import OpenAI

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}


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
    
    var hasImages: Bool {
        self.message.attachments.isEmpty == false
    }
    
    var images: [NSImage] {
        self.message.attachments.filter {
            if case .image(_) = $0 {
                return true
            }
            
            return false
        }
        .compactMap {
            switch $0 {
            case .image(let image):
                return image
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                switch message.role {
                case .assistant:
                    Markdown(message.content)
                        .textSelection(.enabled)
                        .markdownCodeSyntaxHighlighter(.splash(theme:.sundellsColors(withFont: .init(size: 14.0))))
                        .markdownBlockStyle(\.codeBlock, body: { configuration in
                            configuration
                                .padding()
                                .cornerRadius(8)
                                .textSelection(.enabled)
                                .markdownMargin(top: 5, bottom: 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.1))
                                        .stroke(.secondary.opacity(0.1), lineWidth: 1)
                                )
                        })
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    Spacer(minLength: horizontalSpacing)
                case .user:
                    Spacer(minLength: horizontalSpacing)
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .textSelection(.enabled)
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
            
            if self.images.isEmpty == false {
                Grid(alignment: .topTrailing) {
                    ForEach(Array(self.images.chunked(into: 2).enumerated()), id: \.offset) { index, images in
                        HStack {
                            ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                                
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                Color.clear,
                                                lineWidth: 2
                                            )
                                            .background(.clear)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .frame(width: 300)
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
        
        ChatBubble(
            message: .user(
                UUID(),
                "What's in this image?",
                attachments: [
                    .image(.init(imageLiteralResourceName: "profile")),
                    .image(.init(imageLiteralResourceName: "profile")),
                    .image(.init(imageLiteralResourceName: "profile")),
                ]
            )
        )
        
        Spacer()
    }
    .padding()
}
