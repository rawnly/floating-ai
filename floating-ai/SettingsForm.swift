//
//  SwiftUIView.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import SwiftUI

struct SettingsForm<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .coordinateSpace(name: "scroll")
    }
}

#Preview {
    SettingsForm {
            HStack {
                Text("HELLO")
                Spacer()
                TextField("", text: .constant(""))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.vertical, 5)
        HStack {
            Text("HELLO")
            Spacer()
            TextField("", text: .constant(""))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.vertical, 5)
    }
    .padding()
    .frame(width: 600, height: 300)
}
