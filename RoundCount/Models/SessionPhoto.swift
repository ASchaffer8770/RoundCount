//
//  SessionPhoto.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

import Foundation
import SwiftData
import Combine

@Model
final class SessionPhoto {
    var id: UUID
    var filePath: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify) var session: SessionV2?
    @Relationship(deleteRule: .nullify) var run: FirearmRun?

    init(filePath: String, session: SessionV2? = nil, run: FirearmRun? = nil, createdAt: Date = Date()) {
        self.id = UUID()
        self.filePath = filePath
        self.createdAt = createdAt
        self.session = session
        self.run = run
    }
}
