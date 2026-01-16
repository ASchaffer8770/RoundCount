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

    init(firearm: Firearm, ammo: AmmoProduct?, rounds: Int, date: Date, notes: String?) {
        self.id = UUID()
        self.firearm = firearm
        self.ammo = ammo
        self.rounds = rounds
        self.date = date
        self.notes = notes
    }

}
