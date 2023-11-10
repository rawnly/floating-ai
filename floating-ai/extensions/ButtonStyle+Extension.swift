//
//  buttonStyles.swift
//  Floating AI
//
//  Created by Federico Vitale on 08/11/23.
//

import Foundation
import SwiftUI

struct BasicButtonStyle: ButtonStyle {
    
    var role: Role
    
    enum Role {
        case danger
        case standard
    }
    
    var background: some ShapeStyle {
        switch self.role {
        case .danger:
            return Color.red
        default:
            return Color(nsColor: .textColor)
        }
    }
    
    var foreground: some ShapeStyle {
        switch self.role {
        case .danger:
            return Color.white
        default:
            return Color(nsColor: .clear)
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .foregroundStyle(self.foreground)
            .background(self.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct DangerButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View {
        Button(action: { configuration.trigger() }) {
            configuration.label
        }
        .buttonStyle(BasicButtonStyle(role: .danger))
    }
}
