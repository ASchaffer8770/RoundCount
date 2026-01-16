//
//  AmmoProduct.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import Foundation
import SwiftData

enum BulletType: String, CaseIterable, Identifiable {
    case fmj = "FMJ"
    case jhp = "JHP"
    case frangible = "Frangible"
    case lead = "Lead"
    case other = "Other"

    var id: String { rawValue }
}

@Model
final class AmmoProduct {
    @Attribute(.unique) var id: UUID

    // Core shopping fields
    var brand: String              // Federal, CCI, Blazer, Winchester…
    var productLine: String?       // “Blazer Brass”, “White Box”, “American Eagle”
    var caliber: String            // “9mm”, “.223”, “.45 ACP”
    var grain: Int                 // 115, 124, 147…
    var bulletTypeRaw: String      // FMJ/JHP/…

    // Optional but useful
    var quantityPerBox: Int?       // 20/50/100/200
    var caseMaterial: String?      // Brass/Steel/Aluminum
    var notes: String?

    var createdAt: Date

    init(
        brand: String,
        productLine: String? = nil,
        caliber: String,
        grain: Int,
        bulletType: BulletType,
        quantityPerBox: Int? = nil,
        caseMaterial: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.brand = brand
        self.productLine = productLine
        self.caliber = caliber
        self.grain = grain
        self.bulletTypeRaw = bulletType.rawValue
        self.quantityPerBox = quantityPerBox
        self.caseMaterial = caseMaterial
        self.notes = notes
        self.createdAt = Date()
    }

    var bulletType: BulletType {
        BulletType(rawValue: bulletTypeRaw) ?? .other
    }

    var displayName: String {
        // Example: "CCI Blazer Brass • 9mm • 115gr • FMJ"
        let line = (productLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        let base = line.isEmpty ? brand : "\(brand) \(line)"
        return "\(base) • \(caliber) • \(grain)gr • \(bulletTypeRaw)"
    }
}

