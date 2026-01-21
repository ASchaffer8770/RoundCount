//
//  FirearmRun.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/19/26.
//
import Foundation
import SwiftData

@Model
final class FirearmRun {
    @Attribute(.unique) var id: UUID

    @Relationship var firearm: Firearm
    @Relationship var session: SessionV2

    var startedAt: Date
    var endedAt: Date?

    var rounds: Int
    var malfunctionsCount: Int
    var notes: String?

    // ✅ NEW: selected mag for this run (persisted)
    @Relationship var selectedMagazine: FirearmMagazine?

    // ✅ NEW: malfunction breakdown (persisted)
    @Relationship(deleteRule: .cascade) var malfunctions: [RunMalfunction] = []

    init(
        firearm: Firearm,
        startedAt: Date,
        endedAt: Date? = nil,
        rounds: Int = 0,
        malfunctionsCount: Int = 0,
        notes: String? = nil,
        session: SessionV2,
        selectedMagazine: FirearmMagazine? = nil
    ) {
        self.id = UUID()
        self.firearm = firearm
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.rounds = rounds
        self.malfunctionsCount = malfunctionsCount
        self.notes = notes
        self.session = session
        self.selectedMagazine = selectedMagazine
    }

    var durationSeconds: Int {
        let end = endedAt ?? Date()
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }
}
