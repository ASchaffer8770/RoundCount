//
//  RootTabView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var entitlements: Entitlements

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }

            FirearmsView()
                .tabItem { Label("Firearms", systemImage: "scope") }

            LogSessionView()
                .tabItem { Label("Log", systemImage: "plus.circle") }
        }
    .environmentObject(entitlements)
    }
}
