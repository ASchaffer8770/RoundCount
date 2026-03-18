import SwiftUI

// MARK: - View Extension

extension View {
    /// Registers this view's global frame with the coach mark system.
    func coachMarkAnchor(id: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CoachMarkFrameKey.self,
                    value: [id: proxy.frame(in: .global)]
                )
            }
        )
    }
}

// MARK: - Root Overlay

/// Drop this once inside RootTabView. It draws the active coach mark over everything.
struct CoachMarkRootOverlay: View {
    @EnvironmentObject private var manager: CoachMarkManager

    var body: some View {
        if manager.activeSequenceID != nil,
           let step = manager.currentStep,
           let spotlightRect = manager.frames[step.anchorID] {
            let totalSteps = manager.activeSequenceID.map { manager.steps(for: $0).count } ?? 1
            CoachMarkOverlayView(
                spotlightRect: spotlightRect,
                step: step,
                totalSteps: totalSteps,
                currentIndex: manager.stepIndex,
                onNext: { withAnimation(.easeInOut(duration: 0.2)) { manager.advance() } },
                onSkip: { manager.skip() }
            )
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }
}

// MARK: - Overlay Content

private struct CoachMarkOverlayView: View {
    let spotlightRect: CGRect
    let step: CoachMarkStep
    let totalSteps: Int
    let currentIndex: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    private let padding: CGFloat = 10
    private let radius: CGFloat = 14

    private var paddedSpotlight: CGRect {
        spotlightRect.insetBy(dx: -padding, dy: -padding)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                dimmingLayer(size: proxy.size)

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Brand.accent.opacity(0.9), lineWidth: 1.5)
                    .frame(width: paddedSpotlight.width, height: paddedSpotlight.height)
                    .position(x: paddedSpotlight.midX, y: paddedSpotlight.midY)

                tooltip(screenSize: proxy.size)
            }
        }
    }

    // Dimmed layer with a spotlight hole punched out via even-odd fill.
    private func dimmingLayer(size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRoundedRect(
                in: paddedSpotlight,
                cornerSize: CGSize(width: radius, height: radius)
            )
        }
        .fill(Color.black.opacity(0.72), style: FillStyle(eoFill: true))
    }

    private func tooltip(screenSize: CGSize) -> some View {
        let tooltipWidth = min(screenSize.width - 48, 320)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(step.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if totalSteps > 1 {
                    stepDots
                }
            }

            Text(step.message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            HStack {
                if totalSteps > 1 {
                    Button("Skip") { onSkip() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Button(currentIndex == totalSteps - 1 ? "Got it" : "Next") { onNext() }
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Brand.accent)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.45), radius: 18, y: 6)
        )
        .frame(width: tooltipWidth)
        .position(tooltipPosition(tooltipWidth: tooltipWidth, screenSize: screenSize))
    }

    private var stepDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Circle()
                    .fill(i == currentIndex ? Brand.accent : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func tooltipPosition(tooltipWidth: CGFloat, screenSize: CGSize) -> CGPoint {
        let margin: CGFloat = 24
        let tooltipHeight: CGFloat = 160
        let centerX = screenSize.width / 2
        let rect = paddedSpotlight

        let spaceBelow = screenSize.height - rect.maxY
        let spaceAbove = rect.minY

        if spaceBelow >= spaceAbove {
            // More room below — place tooltip under the spotlight
            let y = min(rect.maxY + 12 + tooltipHeight / 2, screenSize.height - tooltipHeight / 2 - margin)
            return CGPoint(x: centerX, y: y)
        } else {
            // More room above — place tooltip above the spotlight
            let y = max(rect.minY - 12 - tooltipHeight / 2, tooltipHeight / 2 + margin)
            return CGPoint(x: centerX, y: y)
        }
    }
}
