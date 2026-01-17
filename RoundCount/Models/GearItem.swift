//
//  GearItem.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import Foundation
import SwiftData

enum GearType: String, Codable, CaseIterable, Identifiable {
    case optic, light, laser, grip, magwell, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .optic: return "Optic"
        case .light: return "Light"
        case .laser: return "Laser"
        case .grip: return "Grip"
        case .magwell: return "Magwell"
        case .other: return "Other"
        }
    }
}

struct BatteryInfo: Codable, Hashable {
    var batteryType: String?      // e.g., "CR1632", "CR2032", "123A"
    var installedAt: Date?        // when installed/changed
    var notes: String?

    // Future hooks
    var roundsSinceChange: Int?
    var secondsSinceChange: Int?
}

@Model
final class GearItem {
    @Attribute(.unique) var id: UUID

    var typeRaw: String
    var brand: String
    var model: String
    var notes: String?

    // Optional battery tracking (Codable)
    var battery: BatteryInfo?

    var createdAt: Date

    @Relationship var setup: FirearmSetup

    init(
        setup: FirearmSetup,
        type: GearType,
        brand: String,
        model: String,
        notes: String? = nil,
        battery: BatteryInfo? = nil
    ) {
        self.id = UUID()
        self.setup = setup
        self.typeRaw = type.rawValue
        self.brand = brand
        self.model = model
        self.notes = notes
        self.battery = battery
        self.createdAt = .now
    }

    var type: GearType { GearType(rawValue: typeRaw) ?? .other }
    var displayName: String { "\(brand) \(model)".trimmingCharacters(in: .whitespacesAndNewlines) }
}
