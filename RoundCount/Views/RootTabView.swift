//
//  RootTabView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var tabRouter: AppTabRouter

    var body: some View {
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
    }
}
