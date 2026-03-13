import SwiftUI

struct OnboardingView: View {
    let onFinish: (OnboardingCompletionAction) -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        .init(
            stepLabel: "Step 1 of 5",
            title: "Welcome to RoundCount",
            subtitle: "Track firearms, log range sessions, monitor round count, and keep your shooting history organized in one place.",
            systemImage: "scope",
            accent: Brand.accent
        ),
        .init(
            stepLabel: "Step 2 of 5",
            title: "Add a firearm first",
            subtitle: "Firearms are the foundation of your data. Add your first firearm so RoundCount can track usage, sessions, and round count over time.",
            systemImage: "shield.lefthalf.filled",
            accent: Brand.accent
        ),
        .init(
            stepLabel: "Step 3 of 5",
            title: "Ammo tracking is optional",
            subtitle: "Add ammo products when you want deeper insight into caliber usage, ammo consumption, and what you shot during each session.",
            systemImage: "circle.grid.cross",
            accent: Brand.accent
        ),
        .init(
            stepLabel: "Step 4 of 5",
            title: "Start a session at the range",
            subtitle: "A session represents a full range visit. Start one when you begin shooting, then record the activity that happens during that trip.",
            systemImage: "timer",
            accent: Brand.accent
        ),
        .init(
            stepLabel: "Step 5 of 5",
            title: "One session, multiple firearm runs",
            subtitle: "Each session can contain one or more firearm runs. A firearm run captures the gun used, rounds fired, notes, malfunctions, and more.",
            systemImage: "list.bullet.rectangle.portrait",
            accent: Brand.accent
        )
    ]

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black,
                    Brand.accent.opacity(0.08),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            if currentPage < pages.count - 1 {
                Button("Skip") {
                    onFinish(.exploreApp)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var bottomControls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Brand.accent : Color.white.opacity(0.2))
                        .frame(width: index == currentPage ? 26 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }

            if currentPage == pages.count - 1 {
                VStack(spacing: 12) {
                    Button {
                        onFinish(.addFirstFirearm)
                    } label: {
                        Text("Add My First Firearm")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Brand.accent)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onFinish(.exploreApp)
                    } label: {
                        Text("Explore App First")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.06))
                            .foregroundStyle(.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: handlePrimaryAction) {
                    Text("Next")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Brand.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handlePrimaryAction() {
        guard currentPage < pages.count - 1 else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            currentPage += 1
        }
    }
}

private struct OnboardingPage {
    let stepLabel: String
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.accent.opacity(0.14))
                    .frame(width: 220, height: 220)
                    .blur(radius: 18)

                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 180, height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(page.accent.opacity(0.45), lineWidth: 1)
                    )

                Image(systemName: page.systemImage)
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(page.accent)
            }

            VStack(spacing: 14) {
                Text(page.stepLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(page.accent.opacity(0.95))
                    .tracking(0.8)

                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            Spacer()
        }
    }
}
