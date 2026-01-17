//
//  FirearmSetup.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import Foundation
import SwiftData

@Model
final class FirearmSetup {
    @Attribute(.unique) var id: UUID

    var name: String
    var isActive: Bool
    var notes: String?
    var createdAt: Date

    @Relationship var firearm: Firearm
    @Relationship(deleteRule: .cascade) var gear: [GearItem] = []

    init(
        firearm: Firearm,
        name: String,
        isActive: Bool = true,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.firearm = firearm
        self.name = name
        self.isActive = isActive
        self.notes = notes
        self.createdAt = .now
    }
}
