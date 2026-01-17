//
//  SessionPhoto.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import Foundation
import SwiftData

@Model
final class SessionPhoto {
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    /// Relative path within Documents/Application Support, e.g. "Sessions/<sessionId>/<photoId>.jpg"
    var relativePath: String

    var caption: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        relativePath: String,
        caption: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.relativePath = relativePath
        self.caption = caption
    }
}

