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
    var isEmpty: Bool = false
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        isLoading: Bool,
        isEmpty: Bool,
        onSubmit: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self.text = text
        self.isLoading = isLoading
        self.isEmpty = isEmpty
        self.onSubmit = onSubmit
    }
    
    @State
    var gradientDirection: [UnitPoint] = [.top, .bottom]
    
    
    var body: some View {
        ZStack(alignment: .trailing) {
//            Rectangle()
//                .fill(.ultraThinMaterial)
//                .frame(maxHeight: 50)
//                .blur(radius: 5)
//                .zIndex(0)
//                .padding(.top, -10)
//                .transition(.opacity)
            
            VStack {
                HStack {
                    if self.isEmpty {
                        Text("Press Enter to submit")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        Spacer()
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: self.isEmpty)
                
                ZStack(alignment: .trailing) {
                    TextField(self.placeholder, text: self.text, axis: .vertical)
                        .lineLimit(10, reservesSpace: false)
                        .multilineTextAlignment(.leading)
                        .focused($isFocused)
                        .backgroundStyle(Color.accentColor)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(Font.system(size: 12))
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
                        .overlay(content: {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(self.isFocused ? 0.3 : 0.2), Color.secondary.opacity(1)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                                .background(.clear)
                        })
                        .onSubmit { self.onSubmit() }
                        .zIndex(1)
                    
                    if self.isLoading {
                        ProgressView()
                            .padding(.trailing, 15)
                            .controlSize(.small)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                            .transition(.opacity)
                            .zIndex(2)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: self.isLoading)
                .background(.ultraThinMaterial)
//                ._visualEffect(material: .sidebar)
                .cornerRadius(8)
            }
            .zIndex(1)
        }
    }
}
