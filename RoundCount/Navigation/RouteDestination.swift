import SwiftUI
import SwiftData

struct RouteDestination: View {
    let route: AppRoute
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        switch route {

        // MARK: - Tab handoffs
        case .firearmsIndex:
            // Prefer switching tabs instead of stacking FirearmsView on Dashboard stack
            tabHandoff(.firearms)

        case .ammoIndex:
            tabHandoff(.ammo)

        // MARK: - Screens
        case .analyticsDashboard:
            AnalyticsDashboardView()

        // MARK: - Details
        case .firearmDetail(let pid):
            if let firearm = modelContext.model(for: pid) as? Firearm {
                FirearmDetailView(firearm: firearm)
            } else {
                missing("Firearm not found")
            }

        case .sessionDetail(let sessionID):
            // IMPORTANT: call your session detail screen using the ID
            // (this fixes your earlier “have session:, expected sessionID:” error)
            SessionDetailView(sessionID: sessionID)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func tabHandoff(_ tab: AppTab) -> some View {
        // Switch tab and pop that tab to root so the user lands cleanly.
        Color.clear
            .onAppear {
                router.selectedTab = tab
                router.popToRoot(of: tab)
            }
    }

    private func missing(_ title: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: "exclamationmark.triangle",
            description: Text("This item may have been deleted or could not be loaded.")
        )
        .padding()
    }
}
