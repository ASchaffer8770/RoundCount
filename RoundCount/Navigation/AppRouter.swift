//
//  AppRouter.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/22/26.
//

import SwiftUI
import Combine
import SwiftData

@MainActor
final class AppRouter: ObservableObject {

    @Published var selectedTab: AppTab = .dashboard

    // Separate stacks per tab
    @Published var dashboardPath: [AppRoute] = []
    @Published var firearmsPath: [AppRoute] = []
    @Published var ammoPath: [AppRoute] = []
    @Published var sessionsPath: [AppRoute] = []
    @Published var settingsPath: [AppRoute] = []

    func pathBinding(for tab: AppTab) -> Binding<[AppRoute]> {
        switch tab {
        case .dashboard:
            return Binding(get: { self.dashboardPath }, set: { self.dashboardPath = $0 })
        case .firearms:
            return Binding(get: { self.firearmsPath }, set: { self.firearmsPath = $0 })
        case .ammo:
            return Binding(get: { self.ammoPath }, set: { self.ammoPath = $0 })
        case .sessions:
            return Binding(get: { self.sessionsPath }, set: { self.sessionsPath = $0 })
        case .settings:
            return Binding(get: { self.settingsPath }, set: { self.settingsPath = $0 })
        }
    }

    func popToRoot(of tab: AppTab) {
        switch tab {
        case .dashboard: dashboardPath.removeAll()
        case .firearms: firearmsPath.removeAll()
        case .ammo: ammoPath.removeAll()
        case .sessions: sessionsPath.removeAll()
        case .settings: settingsPath.removeAll()
        }
    }

    // Optional convenience
    func openFirearm(_ id: PersistentIdentifier, switchToTab: Bool = true) {
        if switchToTab { selectedTab = .firearms }
        firearmsPath.append(.firearmDetail(id))
    }
}
