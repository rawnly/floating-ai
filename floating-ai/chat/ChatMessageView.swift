//
//  ChatMessageView.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import MarkdownUI
import SwiftUI
import OpenAI

struct ChatMessageView: View {
    @State private var color = Color.clear
    
    typealias Kind = Chat.Role
    
    var text: String;
    var style: Self.Kind
    
    init(_ text: String, style: Self.Kind) {
        self.text = text
        self.style = style
    }
    
    
    var body: some View {
        HStack(alignment: .top) {
            if self.style == Self.Kind.user {
                Spacer()
            }
            if self.style == Self.Kind.assistant {
                Image(systemName: "gear")
                    .font(.title)
            }
            Markdown(self.text)
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
                .padding(.top, 5)
                .selectionDisabled(false)
            if self.style == Self.Kind.user {
                Image(systemName: "person.circle.fill")
                    .font(.title)
            }
            if self.style == Self.Kind.assistant {
                Spacer()
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(self.color)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.2)) {
                if hovered {
                    self.color = .secondary.opacity(0.1)
                } else {
                    self.color = .clear
                }
            }
        }
        .cornerRadius(8)
    }
}

