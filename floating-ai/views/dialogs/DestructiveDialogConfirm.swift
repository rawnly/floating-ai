//
//  DestructiveDialogConfirm.swift
//  Floating AI
//
//  Created by Federico Vitale on 08/11/23.
//

import SwiftUI

struct DialogModifier<V: View>: ViewModifier {
    @Binding var isPresenting: Bool
    let view: (_ isPresenting: Binding<Bool>) -> V
    
    func body(content: Content) -> some View {
        ZStack(alignment: .center) {
            content
            
            if isPresenting {
                Rectangle()
                    .ignoresSafeArea(edges: .all)
                    .foregroundStyle(.black.opacity(0.3))
                
                view(self.$isPresenting)
            }
        }
    }
}

struct DestructiveConfirmDialog: View {
    @Binding var isPresented: Bool
    
    let title: String
    let onConfirm: () -> Void
    
    let description: String?
    
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 32))
                .padding(.top)
                .padding(.bottom, 5)
            
            Text(self.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.bottom, 5)
            
            if let description = self.description {
                Text(description)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            
            HStack {
                Button("Cancel", role: .cancel) {
                    self.isPresented = false
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    .clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button("Continue") {
                    self.onConfirm()
                    self.isPresented = false
                }
                .buttonStyle(DangerButtonStyle())
            }.padding(.top, 10)
        }
        .padding(.vertical)
        .padding(.horizontal, 30)
        .background(.ultraThinMaterial)
        .shadow(color: Color.black.opacity(0.3), radius: 5)
        .cornerRadius(8)
    }
}

#Preview {
    DestructiveConfirmDialog(isPresented: Binding<Bool>(
        get: { return true },
        set: { _ in }
    ), title: "Are you sure?", onConfirm: {
        
    }, description: "This action is not reversible")
}
