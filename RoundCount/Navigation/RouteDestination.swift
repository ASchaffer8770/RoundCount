//
//  RouteDestination.swift
//  RoundCount
//

import SwiftUI
import SwiftData

@ViewBuilder
func RouteDestination(_ route: AppRoute) -> some View {
    switch route {

    // Tab root handoffs
    case .firearmsIndex:
        FirearmsView()

    case .ammoIndex:
        AmmoView()

    // Screens
    case .analyticsDashboard:
        AnalyticsDashboardView()

    // Details
    case .firearmDetail(let pid):
        FirearmDetailRoute(pid: pid)

    case .sessionDetail(let sessionID):
        SessionDetailView(sessionID: sessionID)
    }
}

// MARK: - Firearm Detail (SwiftData resolution)

private struct FirearmDetailRoute: View {
    let pid: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let firearm = modelContext.model(for: pid) as? Firearm {
            FirearmDetailView(firearm: firearm)
        } else {
            ContentUnavailableView(
                "Firearm not found",
                systemImage: "scope",
                description: Text("This firearm may have been deleted.")
            )
        }
    }
}
