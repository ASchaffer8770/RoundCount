import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var date: Date
    var rounds: Int
    var notes: String?

    @Relationship var firearm: Firearm
    @Relationship var ammo: AmmoProduct?

    // ✅ Session v2 (Pro)
    var durationSeconds: Int?

    @Relationship(deleteRule: .cascade) var malfunctions: MalfunctionSummary?
    @Relationship(deleteRule: .cascade) var photos: [SessionPhoto] = []

    init(
        firearm: Firearm,
        ammo: AmmoProduct?,
        rounds: Int,
        date: Date,
        notes: String?,
        durationSeconds: Int? = nil,
        malfunctions: MalfunctionSummary? = nil
    ) {
        self.id = UUID()
        self.firearm = firearm
        self.ammo = ammo
        self.rounds = rounds
        self.date = date
        self.notes = notes
        self.durationSeconds = durationSeconds
        self.malfunctions = malfunctions
    }
}
