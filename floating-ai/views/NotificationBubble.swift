//
//  NotificationBubble.swift
//  Floating AI
//
//  Created by Federico Vitale on 06/11/23.
//

import SwiftUI

struct NotificationBubble: View {
    let text: String
    
    var body: some View {
        Text(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white)
            .foregroundStyle(.black)
            .shadow(color: .black.opacity(0.25), radius: 10)
            .clipShape(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    NotificationBubble(text: "Hello World")
        .padding()
}
