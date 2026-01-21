//
//  SessionV2.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/20/26.
//

import Foundation
import SwiftData

@Model
final class SessionV2 {
    @Attribute(.unique) var id: UUID

    // Core identity
    var startedAt: Date
    var endedAt: Date?

    // Optional freeform notes
    var notes: String?

    // Relationships
    @Relationship(deleteRule: .cascade) var runs: [FirearmRun] = []

    // Future (keep placeholders here if you want):
    // @Relationship(deleteRule: .cascade) var photos: [SessionPhoto] = []

    init(startedAt: Date = Date(), endedAt: Date? = nil, notes: String? = nil) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
    }

    // MARK: - Derived analytics (computed, not stored)

    var durationSeconds: Int {
        let end = endedAt ?? Date()
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }

    var totalRounds: Int {
        runs.reduce(0) { $0 + $1.rounds }
    }

    var totalMalfunctions: Int {
        runs.reduce(0) { $0 + $1.malfunctionsCount }
    }
}

