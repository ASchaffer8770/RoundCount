import Foundation
import SwiftData

enum FirearmClass: String, CaseIterable, Identifiable {
    case microCompact = "Micro-Compact"
    case subcompact = "Subcompact"
    case compact = "Compact"
    case fullSize = "Full Size"
    case competition = "Competition"
    case other = "Other"

    var id: String { rawValue }
}

@Model
final class Firearm {
    @Attribute(.unique) var id: UUID

    // Identity
    var brand: String
    var model: String
    var caliber: String
    var firearmClassRaw: String

    // ✅ Optional private field
    var serialNumber: String?

    // Dates
    var purchaseDate: Date?
    var lastUsedDate: Date?

    // Tracking
    var totalRounds: Int
    var createdAt: Date

    init(
        brand: String,
        model: String,
        caliber: String,
        firearmClass: FirearmClass = .other,
        serialNumber: String? = nil,
        purchaseDate: Date? = nil,
        lastUsedDate: Date? = nil
    ) {
        self.id = UUID()
        self.brand = brand
        self.model = model
        self.caliber = caliber
        self.firearmClassRaw = firearmClass.rawValue
        self.serialNumber = serialNumber
        self.purchaseDate = purchaseDate
        self.lastUsedDate = lastUsedDate
        self.totalRounds = 0
        self.createdAt = Date()
    }

    var firearmClass: FirearmClass {
        FirearmClass(rawValue: firearmClassRaw) ?? .other
    }

    var displayName: String {
        "\(brand) \(model)"
    }
}
