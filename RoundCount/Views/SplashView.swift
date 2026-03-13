import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentVisible = false
    @State private var glowExpanded = false
    @State private var ringTrim: CGFloat = 0
    @State private var sweepX: CGFloat = -260
    @State private var gridOpacity: CGFloat = 0
    @State private var titleOffset: CGFloat = 10
    @State private var badgeOffset: CGFloat = 14
    @State private var badgeScale: CGFloat = 0.92
    @State private var pulse = false

    private let brand = Brand.accent
    private let bg = Color.black

    var body: some View {
        ZStack {
            bg
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black,
                    brand.opacity(0.08),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TacticalGrid(color: brand)
                .opacity(gridOpacity)
                .blendMode(.screen)
                .ignoresSafeArea()

            Circle()
                .fill(brand.opacity(0.13))
                .frame(width: 520, height: 520)
                .blur(radius: 70)
                .scaleEffect(glowExpanded ? 1.06 : 0.94)
                .opacity(contentVisible ? 1 : 0)

            Circle()
                .stroke(brand.opacity(0.08), lineWidth: 1)
                .frame(width: 320, height: 320)
                .blur(radius: 1)
                .scaleEffect(glowExpanded ? 1.02 : 0.98)
                .opacity(contentVisible ? 1 : 0)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, brand.opacity(0.14), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 140, height: 900)
                .rotationEffect(.degrees(12))
                .offset(x: sweepX)
                .blur(radius: 10)
                .opacity(contentVisible ? 1 : 0)
                .blendMode(.screen)

            VStack(spacing: 18) {
                ZStack {
                    ReticleRing(color: brand, trim: ringTrim)
                        .frame(width: 156, height: 156)
                        .opacity(contentVisible ? 1 : 0)
                        .scaleEffect(contentVisible ? 1 : 0.94)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .frame(width: 126, height: 126)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(brand.opacity(0.48), lineWidth: 1)
                        )
                        .shadow(color: brand.opacity(0.24), radius: 24, y: 0)
                        .overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.22), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .scaleEffect(badgeScale)
                        .offset(y: badgeOffset)
                        .opacity(contentVisible ? 1 : 0)

                    Text("RC")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(brand)
                        .shadow(color: brand.opacity(0.55), radius: 12)
                        .scaleEffect(contentVisible ? 1 : 0.94)
                        .offset(y: badgeOffset)
                        .opacity(contentVisible ? 1 : 0)
                }

                VStack(spacing: 7) {
                    Text("RoundCount")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(y: titleOffset)
                        .opacity(contentVisible ? 1 : 0)

                    Text("SESSION • AMMO • MAINTENANCE")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .tracking(1.6)
                        .offset(y: titleOffset)
                        .opacity(contentVisible ? 1 : 0)
                }

                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(brand)
                            .frame(width: 7, height: 7)
                            .scaleEffect(pulse ? 1.0 : 0.58)
                            .opacity(pulse ? 1.0 : 0.5)
                            .animation(
                                reduceMotion
                                    ? .none
                                    : .easeInOut(duration: 0.65)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.14),
                                value: pulse
                            )
                    }
                }
                .padding(.top, 8)
                .opacity(contentVisible ? 1 : 0)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        contentVisible = true
        pulse = true

        if reduceMotion {
            ringTrim = 1
            gridOpacity = 0.22
            glowExpanded = true
            titleOffset = 0
            badgeOffset = 0
            badgeScale = 1
            sweepX = 220
            return
        }

        withAnimation(.easeOut(duration: 0.55)) {
            badgeOffset = 0
            badgeScale = 1
        }

        withAnimation(.easeOut(duration: 0.65).delay(0.08)) {
            titleOffset = 0
        }

        withAnimation(.easeInOut(duration: 0.95)) {
            ringTrim = 1
        }

        withAnimation(.easeOut(duration: 0.85).delay(0.1)) {
            gridOpacity = 0.26
        }

        withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
            glowExpanded = true
        }

        withAnimation(.easeInOut(duration: 1.45).delay(0.15)) {
            sweepX = 240
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
                .stroke(
                    color.opacity(0.85),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.35), radius: 14)

            ForEach(0..<12, id: \.self) { i in
                Rectangle()
                    .fill(color.opacity(0.6))
                    .frame(width: i % 3 == 0 ? 3 : 2, height: i % 3 == 0 ? 14 : 9)
                    .offset(y: -81)
                    .rotationEffect(.degrees(Double(i) * 30))
                    .opacity(trim > 0.35 ? 1 : 0)
            }

            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
                .frame(width: 120, height: 120)
        }
    }
}

private struct TacticalGrid: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
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

            context.stroke(path, with: .color(color.opacity(0.12)), lineWidth: 1)
        }
    }
}
