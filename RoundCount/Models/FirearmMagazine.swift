//
//  FirearmMagazine.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/20/26.
//

import Foundation
import SwiftData

@Model
final class FirearmMagazine {
    @Attribute(.unique) var id: UUID

    var capacity: Int
    var label: String?
    var createdAt: Date

    @Relationship var firearm: Firearm

    init(firearm: Firearm, capacity: Int, label: String? = nil) {
        self.id = UUID()
        self.firearm = firearm
        self.capacity = capacity
        self.label = label
        self.createdAt = Date()
    }

    var displayName: String {
        if let label, !label.isEmpty { return "\(capacity) • \(label)" }
        return "\(capacity) rounds"
    }
}

