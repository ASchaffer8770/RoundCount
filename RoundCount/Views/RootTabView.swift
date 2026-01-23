// Views/RootTabView.swift
import SwiftUI

struct RootTabView: View {
    @StateObject private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {

            NavigationStack(path: router.pathBinding(for: .dashboard)) {
                DashboardView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route)
                    }
            }
            .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            .tag(AppTab.dashboard)

            NavigationStack(path: router.pathBinding(for: .firearms)) {
                FirearmsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route)
                    }
            }
            .tabItem { Label("Firearms", systemImage: "scope") }
            .tag(AppTab.firearms)

            NavigationStack(path: router.pathBinding(for: .ammo)) {
                AmmoView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route)
                    }
            }
            .tabItem { Label("Ammo", systemImage: "circle.grid.cross") }
            .tag(AppTab.ammo)

            NavigationStack(path: router.pathBinding(for: .sessions)) {
                // whatever your sessions list/root is (or DashboardView if sessions are embedded)
                AnalyticsDashboardView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route)
                    }
            }
            .tabItem { Label("Sessions", systemImage: "timer") }
            .tag(AppTab.sessions)

            NavigationStack(path: router.pathBinding(for: .settings)) {
                SettingsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestination(route)
                    }
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .environmentObject(router)
    }
}
