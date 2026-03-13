import SwiftUI

struct RootTabView: View {
    @StateObject private var router = AppRouter()

    let startAction: OnboardingCompletionAction?

    @State private var hasHandledStartAction = false
    @State private var showOnboardingAddFirearm = false

    init(startAction: OnboardingCompletionAction? = nil) {
        self.startAction = startAction
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: router.pathBinding(for: .dashboard)) {
                DashboardView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route: route)
                    }
            }
            .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            .tag(AppTab.dashboard)

            NavigationStack(path: router.pathBinding(for: .firearms)) {
                FirearmsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route: route)
                    }
            }
            .tabItem { Label("Firearms", systemImage: "scope") }
            .tag(AppTab.firearms)

            NavigationStack(path: router.pathBinding(for: .ammo)) {
                AmmoView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route: route)
                    }
            }
            .tabItem { Label("Ammo", systemImage: "circle.grid.cross") }
            .tag(AppTab.ammo)

            NavigationStack(path: router.pathBinding(for: .sessions)) {
                LiveSessionView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route: route)
                    }
            }
            .tabItem { Label("Sessions", systemImage: "timer") }
            .tag(AppTab.sessions)

            NavigationStack(path: router.pathBinding(for: .settings)) {
                SettingsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route: route)
                    }
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .environmentObject(router)
        .sheet(isPresented: $showOnboardingAddFirearm) {
            AddFirearmView()
                .presentationDetents([.large])
        }
        .task {
            guard !hasHandledStartAction else { return }
            hasHandledStartAction = true

            guard let startAction else { return }

            switch startAction {
            case .exploreApp:
                break

            case .addFirstFirearm:
                router.selectedTab = .firearms

                await MainActor.run {
                    showOnboardingAddFirearm = true
                }
            }
        }
    }
}
