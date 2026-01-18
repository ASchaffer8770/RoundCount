//
//  SessionSnapshot.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/18/26.
//

import Foundation

struct SessionSnapshot: Hashable {
    let date: Date
    let rounds: Int
    let durationSeconds: Int
    let malfunctionsTotal: Int

    let setupId: UUID?
    let setupName: String?

    let ammoId: UUID?
    let ammoName: String?

    init(_ s: Session) {
        self.date = s.date
        self.rounds = s.rounds
        self.durationSeconds = s.durationSeconds ?? 0
        self.malfunctionsTotal = s.malfunctions?.total ?? 0

        self.setupId = s.setup?.id
        self.setupName = s.setup?.name

        self.ammoId = s.ammo?.id
        self.ammoName = s.ammo?.displayName
    }
}
