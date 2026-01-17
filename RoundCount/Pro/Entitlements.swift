import SwiftUI
import Combine

enum UserTier: String, Codable {
    case free
    case pro
}

@MainActor
final class Entitlements: ObservableObject {

    // This drives UI updates automatically
    @Published private(set) var tier: UserTier = .free

    // Persist across launches
    @AppStorage("rc.userTier") private var storedTier: String = UserTier.free.rawValue

    init() {
        tier = UserTier(rawValue: storedTier) ?? .free
    }

    var isPro: Bool { tier == .pro }

    func setTier(_ newTier: UserTier) {
        tier = newTier
        storedTier = newTier.rawValue
    }

    // MARK: - Limits (Free tier)
    var freeFirearmLimit: Int { 1 }
}
