//
//  SplashView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appear = false
    @State private var pulse = false
    @State private var trim: CGFloat = 0
    @State private var sweepX: CGFloat = -220
    @State private var gridOpacity: CGFloat = 0

    // Prefer the asset color you already have:
    private let brand = Color("BrandAccent")
    private let bg = Color.black

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            TacticalGrid(color: brand)
                .opacity(gridOpacity)
                .blendMode(.screen)
                .ignoresSafeArea()

            Circle()
                .fill(brand.opacity(0.12))
                .frame(width: 520, height: 520)
                .blur(radius: 60)
                .scaleEffect(pulse ? 1.03 : 0.97)
                .opacity(appear ? 1 : 0)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, brand.opacity(0.12), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 140, height: 900)
                .rotationEffect(.degrees(12))
                .offset(x: sweepX)
                .blur(radius: 8)
                .opacity(appear ? 1 : 0)
                .blendMode(.screen)

            VStack(spacing: 16) {
                ZStack {
                    ReticleRing(color: brand, trim: trim)
                        .frame(width: 150, height: 150)
                        .opacity(appear ? 1 : 0)
                        .scaleEffect(appear ? 1 : 0.92)

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 124, height: 124)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(brand.opacity(0.55), lineWidth: 1)
                        )
                        .shadow(color: brand.opacity(0.25), radius: 22)
                        .opacity(appear ? 1 : 0)
                        .scaleEffect(appear ? 1 : 0.9)

                    // TODO: Replace with your logo asset later
                    Text("RC")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(brand)
                        .shadow(color: brand.opacity(0.6), radius: 12)
                        .opacity(appear ? 1 : 0)
                }

                VStack(spacing: 6) {
                    Text("RoundCount")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(appear ? 1 : 0)

                    Text("SESSION • AMMO • MAINTENANCE")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .tracking(1.6)
                        .opacity(appear ? 1 : 0)
                }

                HStack(spacing: 10) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(brand)
                            .frame(width: 7, height: 7)
                            .scaleEffect(pulse ? 1 : 0.55)
                            .opacity(pulse ? 1 : 0.55)
                            .animation(
                                reduceMotion ? .none :
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.12),
                                value: pulse
                            )
                    }
                }
                .padding(.top, 10)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            appear = true

            if reduceMotion {
                trim = 1
                gridOpacity = 0.25
                pulse = true
                sweepX = 220
            } else {
                withAnimation(.easeInOut(duration: 0.9)) { trim = 1 }
                withAnimation(.easeOut(duration: 0.8).delay(0.15)) { gridOpacity = 0.28 }
                pulse = true

                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: false)) {
                    sweepX = 220
                }
            }
        }
    }
}

private struct ReticleRing: View {
    let color: Color
    let trim: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: trim)
                .stroke(color.opacity(0.85),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.35), radius: 14)

            ForEach(0..<12) { i in
                Rectangle()
                    .fill(color.opacity(0.6))
                    .frame(width: i % 3 == 0 ? 3 : 2,
                           height: i % 3 == 0 ? 14 : 9)
                    .offset(y: -78)
                    .rotationEffect(.degrees(Double(i) * 30))
                    .opacity(trim > 0.35 ? 1 : 0)
            }

            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .frame(width: 118, height: 118)
        }
    }
}

private struct TacticalGrid: View {
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 44
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            ctx.stroke(path, with: .color(color.opacity(0.12)), lineWidth: 1)
        }
    }
}
