//
//  RunMalfunction.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/20/26.
//

import Foundation
import SwiftData

enum MalfunctionKind: String, CaseIterable, Identifiable, Hashable {
    case failureToFeed = "Failure to Feed"
    case failureToExtract = "Failure to Extract"
    case stovepipe = "Stovepipe"
    case failureToEject = "Failure to Eject"
    case lightStrike = "Light Strike"
    case doubleFeed = "Double Feed"
    case failureToLockBack = "Failure to Lock Back"
    case other = "Other"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .failureToFeed: return "FTF"
        case .failureToExtract: return "FTE"
        case .stovepipe: return "Stovepipe"
        case .failureToEject: return "Eject"
        case .lightStrike: return "Strike"
        case .doubleFeed: return "Double"
        case .failureToLockBack: return "No Lock"
        case .other: return "Other"
        }
    }
}

@Model
final class RunMalfunction {
    @Attribute(.unique) var id: UUID

    var kindRaw: String
    var count: Int
    var createdAt: Date

    @Relationship var run: FirearmRun

    init(run: FirearmRun, kind: MalfunctionKind, count: Int = 0) {
        self.id = UUID()
        self.run = run
        self.kindRaw = kind.rawValue
        self.count = count
        self.createdAt = Date()
    }

    var kind: MalfunctionKind {
        MalfunctionKind(rawValue: kindRaw) ?? .other
    }
}

