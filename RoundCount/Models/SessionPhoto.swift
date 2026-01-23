//
//  SessionPhoto.swift
//  RoundCount
//
//  V1: Photos attach to a FirearmRun (target / malfunction)
//

import Foundation
import SwiftData

enum SessionPhotoTag: String, Codable, CaseIterable, Identifiable {
    case target
    case malfunction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .target: return "Target"
        case .malfunction: return "Malfunction"
        }
    }

    var systemImage: String {
        switch self {
        case .target: return "target"
        case .malfunction: return "exclamationmark.triangle.fill"
        }
    }
}

@Model
final class SessionPhoto {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    // Stored as String so SwiftData stays happy
    var tagRaw: String = SessionPhotoTag.target.rawValue

    // Store image bytes (JPEG). externalStorage avoids bloating the main store file.
    @Attribute(.externalStorage) var imageData: Data

    // ✅ Ownership: photo belongs to exactly one run
    @Relationship(inverse: \FirearmRun.photos)
    var run: FirearmRun

    init(run: FirearmRun, imageData: Data, tag: SessionPhotoTag) {
        self.run = run
        self.imageData = imageData
        self.tagRaw = tag.rawValue
        self.createdAt = Date()
    }

    var tag: SessionPhotoTag {
        get { SessionPhotoTag(rawValue: tagRaw) ?? .target }
        set { tagRaw = newValue.rawValue }
    }
}
