import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var tabRouter: AppTabRouter

    var body: some View {
        NavigationStack {
            TabView(selection: $tabRouter.selectedTab) {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "gauge") }
                    .tag(AppTab.dashboard)

                FirearmsView()
                    .tabItem { Label("Firearms", systemImage: "scope") }
                    .tag(AppTab.firearms)

                AmmoView()
                    .tabItem { Label("Ammo", systemImage: "tray.full") }
                    .tag(AppTab.ammo)

                LiveSessionView()
                    .tabItem { Label("Live", systemImage: "timer") }
                    .tag(AppTab.live)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(AppTab.settings)
            }

            // ✅ Single, global destination for SessionV2 details
            .navigationDestination(for: UUID.self) { sessionID in
                SessionDetailView(sessionID: sessionID)
            }
        }
    }
}
