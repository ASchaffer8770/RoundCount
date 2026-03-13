import SwiftUI

enum AppPhase {
    case splash
    case onboarding
    case main
}

enum OnboardingCompletionAction {
    case exploreApp
    case addFirstFirearm
}

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var phase: AppPhase = .splash
    @State private var postOnboardingAction: OnboardingCompletionAction? = nil

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView()
                    .transition(.opacity)

            case .onboarding:
                OnboardingView { action in
                    hasCompletedOnboarding = true
                    postOnboardingAction = action

                    withAnimation(.easeInOut(duration: 0.3)) {
                        phase = .main
                    }
                }
                .transition(.opacity)

            case .main:
                RootTabView(startAction: postOnboardingAction)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: phase)
        .task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)

            await MainActor.run {
                phase = hasCompletedOnboarding ? .main : .onboarding
            }
        }
    }
}
