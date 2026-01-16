//
//  RoundCountApp.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI
import SwiftData

@main
struct RoundCountApp: App {
    @StateObject private var entitlements = Entitlements()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .tint(Brand.accent)
                .environmentObject(entitlements)
        }
        .modelContainer(for: [
            Firearm.self,
            Session.self,
            AmmoProduct.self
        ])
    }
}
