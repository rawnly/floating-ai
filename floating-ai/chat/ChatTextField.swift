//
//  ChatTextField.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import Foundation
import SwiftUI

struct ChatTextField: View {
    @FocusState var isFocused: Bool
    
    var text: Binding<String>
    var isLoading: Bool = false
    var onSubmit: () -> Void
    var placeholder: String
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        isLoading: Bool,
        onSubmit: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self.text = text
        self.isLoading = isLoading
        self.onSubmit = onSubmit
    }
    
    private var borderColor: Color {
        if isFocused {
            return Color.accentColor
        }
        
        return Color.secondary.opacity(0.3)
    }
    
    private var borderWidth: CGFloat {
        if isFocused {
            return 1.5
        }
        
        return 1
    }
    
    
    var body: some View {
        ZStack(alignment: .trailing) {
            TextField(self.placeholder, text: self.text, axis: .vertical)
                .lineLimit(10, reservesSpace: false)
                .multilineTextAlignment(.leading)
                .focused($isFocused)
                .backgroundStyle(Color.accentColor)
                .textFieldStyle(PlainTextFieldStyle())
                .font(Font.system(size: 14).monospaced())
                .disableAutocorrection(false)
                .disabled(self.isLoading)
                .padding()
                .background(Color.clear)
                .cornerRadius(8)
                .onAppear {
                    self.isFocused = true
                }
                .onChange(of: self.isLoading, { _, newValue in
                    self.isFocused = !newValue
                })
                .onTapGesture {
                    print("TAP 1")
                    self.isFocused = true
                }
                .overlay(content: {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            borderColor,
                            lineWidth: borderWidth
                        )
                        .onTapGesture {
                            self.isFocused = true
                        }
                        .background(.clear)
                })
                .onSubmit { self.onSubmit() }
                .zIndex(1)
            
            if self.isLoading {
                ProgressView()
                    .padding(.trailing, 15)
                    .controlSize(.small)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                    .zIndex(2)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}
