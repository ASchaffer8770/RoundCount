//
//  PremiumCardStyle.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

//
//  PremiumCardStyle.swift
//  RoundCount
//

import SwiftUI

struct PremiumCardStyle: ViewModifier {
    var cornerRadius: CGFloat = Brand.Radius.l
    var padding: CGFloat = Brand.Spacing.m

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Brand.cardFill(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Brand.cardStroke(scheme), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(Brand.subtleShadowOpacity(scheme)),
                radius: 10,
                x: 0,
                y: 3
            )
    }
}

extension View {
    func premiumCard(
        cornerRadius: CGFloat = Brand.Radius.l,
        padding: CGFloat = Brand.Spacing.m
    ) -> some View {
        modifier(PremiumCardStyle(cornerRadius: cornerRadius, padding: padding))
    }
}
