//
//  NeonCardStyle.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import SwiftUI

struct NeonCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    var accent: Color = Brand.accent
    var intensity: CGFloat = 1.0

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let isDark = scheme == .dark

        let glowPrimary = (isDark ? 0.55 : 0.30) * intensity
        let glowSecondary = (isDark ? 0.35 : 0.18) * intensity
        let glowTertiary = (isDark ? 0.22 : 0.12) * intensity

        content
            // 1️⃣ Actual card surface (no glow here)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )

            // 2️⃣ Crisp neon edge (outside)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(isDark ? 0.9 : 0.55), lineWidth: 1.2)
            )

            // 3️⃣ TRUE outer glow layers
            .shadow(color: accent.opacity(glowPrimary), radius: 10, x: 0, y: 0)
            .shadow(color: accent.opacity(glowSecondary), radius: 22, x: 0, y: 0)
            .shadow(color: accent.opacity(glowTertiary), radius: 42, x: 0, y: 0)
    }
}

extension View {
    func neonCard(
        cornerRadius: CGFloat = 16,
        intensity: CGFloat = 1.0,
        accent: Color = Brand.accent
    ) -> some View {
        modifier(
            NeonCardStyle(
                cornerRadius: cornerRadius,
                accent: accent,
                intensity: intensity
            )
        )
    }
}
