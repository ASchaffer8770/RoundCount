//
//  Brand.swift
//  RoundCount
//

import SwiftUI

enum Brand {

    // MARK: - Color tokens

    /// Single global accent (already in Assets as BrandAccent)
    static let accent = Color("BrandAccent")

    /// Secondary accent use (rare)
    static let accentSoft = accent.opacity(0.16)

    // MARK: - Layout tokens

    static let screenPadding: CGFloat = 16

    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 14
        static let l: CGFloat = 18
        static let xl: CGFloat = 22
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 14
        static let l: CGFloat = 18
        static let xl: CGFloat = 24
    }

    // MARK: - Typography tokens
    // ✅ Renamed from `Type` -> `Typography` to avoid Swift metatype conflict.

    enum Typography {
        static let title = Font.title2.weight(.bold)
        static let section = Font.headline.weight(.semibold)
        static let body = Font.body
        static let meta = Font.footnote
        static let caption = Font.caption
    }

    // MARK: - Surfaces (dynamic for light/dark)

    static func pageBackground(_ scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return Color(uiColor: .systemBackground)
        } else {
            return Color(uiColor: .systemGroupedBackground)
        }
    }

    static func cardFill(_ scheme: ColorScheme) -> Color {
        Color(uiColor: scheme == .dark ? .secondarySystemBackground : .systemBackground)
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
    }

    static func subtleShadowOpacity(_ scheme: ColorScheme) -> CGFloat {
        scheme == .dark ? 0.0 : 0.10
    }
    
    // MARK: - Accent treatments

    static func accentWash(_ scheme: ColorScheme, strength: CGFloat = 1.0) -> LinearGradient {
        // Subtle “premium” wash. Light mode = barely there; dark = a little richer.
        let a = scheme == .dark ? 0.22 : 0.10
        let b = scheme == .dark ? 0.10 : 0.05

        return LinearGradient(
            colors: [
                Brand.accent.opacity(a * strength),
                Brand.accent.opacity(b * strength),
                Brand.accent.opacity(0.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func iconAccent(_ scheme: ColorScheme) -> Color {
        // Icons lean into brand color just a bit
        scheme == .dark ? Brand.accent.opacity(0.95) : Brand.accent.opacity(0.85)
    }

    static func hairlineAccent(_ scheme: ColorScheme) -> Color {
        // A thin accent border that reads premium
        scheme == .dark ? Brand.accent.opacity(0.35) : Brand.accent.opacity(0.22)
    }

}
