//
//  RoundCountApp.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct RoundCountApp: App {
    @StateObject private var entitlements = Entitlements()
    @StateObject private var store = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(Brand.accent)
                .environmentObject(entitlements)
                .environmentObject(store)
                .task {
                    // ✅ Start listening for transaction updates ASAP
                    store.start()

                    // ✅ Load products (for paywall UI)
                    await store.loadProducts()

                    // ✅ Sync tier (only flips tier when allowBetaProPurchase == true,
                    // unless allowBetaProToggle == true)
                    await entitlements.refreshFromStoreKit()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task { @MainActor in
                        await entitlements.refreshFromStoreKit()
                    }
                }
        }
        .modelContainer(for: [
            Firearm.self,
            FirearmMagazine.self,
            FirearmRun.self,
            RunMalfunction.self,
            FirearmSetup.self,
            GearItem.self,
            SessionV2.self,
            AmmoProduct.self,
            SessionPhoto.self
        ])
    }
}
