//
//  SessionPhoto.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

import Foundation
import SwiftData

@Model
final class SessionPhoto {
    // Give it a real stable ID for SwiftUI
    @Attribute(.unique) var id: UUID

    var filePath: String
    var createdAt: Date

    // Relationships (adjust types to your real model names)
    var session: SessionV2?
    var run: FirearmRun?

    init(filePath: String, session: SessionV2? = nil, run: FirearmRun? = nil, createdAt: Date = Date()) {
        self.id = UUID()
        self.filePath = filePath
        self.createdAt = createdAt
        self.session = session
        self.run = run
    }
}
