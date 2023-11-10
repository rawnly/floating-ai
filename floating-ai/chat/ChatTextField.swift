//
//  ChatTextField.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers


struct ChatTextField: View {
    @FocusState var isFocused: Bool
    
    var isDroppingFile: Bool = false
    
    var text: Binding<String>
    var isLoading: Bool = false
    var onSubmit: () -> Void
    var placeholder: String
    var isEmpty: Bool = false
    var disabled: Bool = false
    var hasFiles: Bool = false
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        isLoading: Bool=false,
        isEmpty: Bool=true,
        disabled: Bool=false,
        isDroppingFile: Bool=false,
        hasFiles: Bool = false,
        onSubmit: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self.text = text
        self.isLoading = isLoading
        self.isEmpty = isEmpty
        self.onSubmit = onSubmit
        self.disabled = disabled
        self.isDroppingFile = isDroppingFile
        self.hasFiles = hasFiles;
    }
    
    @State
    var gradientDirection: [UnitPoint] = [.top, .bottom]
    
    var shouldShowHelper: Bool {
        return self.isEmpty
    }
    
    
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
                    if self.shouldShowHelper && !self.hasFiles {
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
                        .disabled(self.disabled)
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
                                        colors: self.isDroppingFile ? [
                                            Color.accentColor,
                                            Color.accentColor
                                        ] : [
                                            Color.accentColor.opacity(self.isFocused ? 0.3 : 0.2),
                                            Color.secondary.opacity(1)
                                        ],
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
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.25), radius: 16)
            }
            .zIndex(1)
        }
    }
}

struct Thumbnail: View {
    @State
    private var isHover: Bool = false
    
    @State
    private var isSelected: Bool = false
    
    @State
    private var isFocused: Bool = false
    
    let thumbnail: ThumbnailImage
    let onRemove: (_ image: ThumbnailImage) -> Void
    
    init(_ thumbnail: ThumbnailImage, onRemove: @escaping (_ image: ThumbnailImage) -> Void) {
        self.thumbnail = thumbnail
        self.onRemove = onRemove
    }
    
    var body: some View {
        ZStack(alignment: .center) {
            Image(nsImage: self.thumbnail.image)
                .resizable()
                .scaledToFill()
                .cornerRadius(8)
            
            if self.isHover {
                Rectangle()
                    .foregroundStyle(Color.black.opacity(0.5))
                    .scaledToFill()
                    .overlay {
                        Button(role: .destructive) {
                            self.onRemove(self.thumbnail)
                        } label: {
                            Image(systemName: "trash.fill")
                        }
                        .buttonStyle(.plain)
                    }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: self.isHover)
        .onHover(perform: { hovering in
            self.isHover = hovering
        })
        .clipShape(
            RoundedRectangle(cornerRadius: 8)
        )
    }
}

struct ThumbnailImage: Identifiable {
    var id: String = UUID().uuidString
    let image: NSImage
    
    init(_ image: NSImage) {
        self.image = image
    }
    
    init(_ image: NSImage, id: String) {
        self.image = image
        self.id = id
    }
}
