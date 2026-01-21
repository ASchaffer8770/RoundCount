//
//  BrandSurfaceModifiers.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//
//
//  BrandSurfaceModifiers.swift
//  RoundCount
//

import SwiftUI

extension View {

    /// Default neutral card (most UI)
    func surfaceCard(radius: CGFloat = Brand.Radius.l) -> some View {
        modifier(SurfaceCardModifier(radius: radius))
    }

    /// Parent / section card with subtle accent wash
    func accentCard(radius: CGFloat = Brand.Radius.l) -> some View {
        modifier(AccentCardModifier(radius: radius))
    }
}

struct SurfaceCardModifier: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Brand.cardFill(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Brand.cardStroke(scheme), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(Brand.subtleShadowOpacity(scheme)),
                radius: 18,
                x: 0,
                y: 8
            )
            .clipShape(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
    }
}

struct AccentCardModifier: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Brand.cardFill(scheme))

                    // Subtle brand wash — parent cards only
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Brand.accentWash(scheme))
                        .opacity(scheme == .dark ? 0.85 : 0.65)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Brand.hairlineAccent(scheme), lineWidth: 0.9)
            )
            .shadow(
                color: Color.black.opacity(Brand.subtleShadowOpacity(scheme)),
                radius: 22,
                x: 0,
                y: 10
            )
            .clipShape(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
    }
}

