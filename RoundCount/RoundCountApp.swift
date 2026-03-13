import SwiftUI
import SwiftData
import UIKit

@main
struct RoundCountApp: App {
    @StateObject private var entitlements = Entitlements()
    @StateObject private var store = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .tint(Brand.accent)
                .environmentObject(entitlements)
                .environmentObject(store)
                .task {
                    store.start()
                    await store.loadProducts()
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
