//
//  EditableLabel.swift
//  floating-ai
//
//  Created by Federico Vitale on 05/11/23.
//

import SwiftUI

struct EditableLabel: View {
    @State var text: String
    @State var isEditing: Bool = false;
    @State var label: String
    @FocusState var isFocused: Bool
    
    private var onSubmit: ((String) -> Void)?
    
    init(_ label: String) {
        self.init(label: label, nil)
    }
    
    init(label: String, _ onSubmit: ((String) -> Void)?) {
        self.label = label
        self.onSubmit = onSubmit
        self.text = label
    }
    
    var body: some View {
        if isEditing {
            TextField(self.label, text: self.$text)
                .textFieldStyle(PlainTextFieldStyle())
                .focused(self.$isFocused)
                .onSubmit {
                    if self.text != "" {
                        self.label = self.text
                    }
                    
                    self.isEditing = false
                    
                    guard let onSubmit = self.onSubmit else { return }
                    onSubmit(self.label)
                }
                .onChange(of: self.isEditing) { _, value in
                    self.isFocused = value
                }
                .onChange(of: self.isFocused) { _, value in
                    if value { return }
                    
                    if self.text != "" {
                        self.label = self.text
                    }
                    
                    self.isEditing = false
                    
                    guard let onSubmit = self.onSubmit else { return }
                    onSubmit(self.label)
                }
                .lineLimit(1)
        } else {
            Text(self.label)
                .onTapGesture(count: 2) {
                    print("Tapped")
                    self.isEditing.toggle()
                    self.isFocused = true
                }
                .lineLimit(1)
        }
    }
}

#Preview {
    EditableLabel(label: "Hello World", nil)
}
