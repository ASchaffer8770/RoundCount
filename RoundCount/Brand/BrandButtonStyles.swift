//
//  BrandButtonStyles.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

import SwiftUI

enum BrandButtonRole {
    case primary
    case secondary
    case tertiary
    case destructive
}

struct BrandButtonStyle: ButtonStyle {
    let role: BrandButtonRole
    var cornerRadius: CGFloat = Brand.Radius.m
    var height: CGFloat = 48

    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .foregroundStyle(foreground(configuration))
            .background(background(configuration))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border(configuration), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func foreground(_ configuration: Configuration) -> Color {
        switch role {
        case .primary: return .white
        case .destructive: return .white
        case .secondary, .tertiary: return .primary
        }
    }

    private func background(_ configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return Group {
            switch role {
            case .primary:
                Brand.accent.opacity(pressed ? 0.85 : 1.0)

            case .destructive:
                Color.red.opacity(pressed ? 0.85 : 1.0)

            case .secondary:
                // Slightly filled, looks premium and works in dark mode
                Color.secondary.opacity(pressed ? 0.22 : 0.16)

            case .tertiary:
                // Almost flat; for subtle actions
                Color.clear
            }
        }
    }

    private func border(_ configuration: Configuration) -> Color {
        let pressed = configuration.isPressed

        switch role {
        case .primary:
            return Brand.accent.opacity(pressed ? 0.55 : 0.70)
        case .destructive:
            return Color.red.opacity(0.70)
        case .secondary:
            return Brand.cardStroke(scheme).opacity(0.85)
        case .tertiary:
            return Brand.cardStroke(scheme).opacity(configuration.isPressed ? 1.0 : 0.75)
        }
    }
}

extension ButtonStyle where Self == BrandButtonStyle {
    static func brand(_ role: BrandButtonRole) -> BrandButtonStyle {
        BrandButtonStyle(role: role)
    }
}

