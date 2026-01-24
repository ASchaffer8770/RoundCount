import SwiftUI
import Combine
import StoreKit

enum UserTier: String, Codable {
    case free
    case pro
}

@MainActor
final class Entitlements: ObservableObject {

    // PRODUCTION AND TEST FLIGHT FLAGS
    static let allowBetaProToggle = false
    static let allowBetaProPurchase = true

    // This drives UI updates automatically
    @Published private(set) var tier: UserTier = .free

    // Persist across launches (still useful for beta toggle / fallback)
    @AppStorage("rc.userTier") private var storedTier: String = UserTier.free.rawValue

    init() {
        tier = UserTier(rawValue: storedTier) ?? .free
    }

    var isPro: Bool { tier == .pro }

    /// Use this ONLY for the Beta toggle.
    /// When beta toggle is disabled, StoreKit should control entitlements.
    func setTier(_ newTier: UserTier) {
        tier = newTier
        storedTier = newTier.rawValue
    }

    // MARK: - StoreKit Entitlements

    /// Call this after:
    /// - app launch
    /// - successful purchase
    /// - restore
    /// - returning to foreground
    func refreshFromStoreKit() async {
        // If you want the beta toggle to override StoreKit, keep this:
        if Self.allowBetaProToggle {
            // Stored tier remains the source of truth in beta-toggle mode.
            tier = UserTier(rawValue: storedTier) ?? .free
            return
        }

        // If purchases are not enabled yet, do nothing (keeps current tier)
        // You can flip this later when you're ready to turn on real purchases.
        if !Self.allowBetaProPurchase {
            return
        }

        var hasPro = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }

            // ✅ Only monthly + yearly count as Pro
            if tx.productID == StoreKitManager.proMonthlyID || tx.productID == StoreKitManager.proYearlyID {
                hasPro = true
                break
            }
        }

        let resolved: UserTier = hasPro ? .pro : .free
        tier = resolved
        storedTier = resolved.rawValue
    }

    // MARK: - Limits (Free tier)
    var freeFirearmLimit: Int { 1 }
}
