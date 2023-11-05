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
//        .safeAreaInset(edge: .top, spacing: -50) {
//            EffectView(.menu)
//                .transaction { transaction in
//                    transaction.animation = nil
//                }
//                .overlay(alignment: .bottom) {
//                    LinearGradient(
//                        gradient: Gradient(colors: []),
//                        startPoint: .top,
//                        endPoint: .bottom
//                    )
//                    .frame(height: 1)
//                    .padding(.bottom, -1)
//                    .opacity(1)
//                    .transition(.opacity)
//                }
//                .ignoresSafeArea()
//                .frame(height: 0)
//        }
    }
}

#Preview {
    SettingsForm {
        EmptyView()
    }
}
