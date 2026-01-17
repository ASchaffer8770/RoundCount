//
//  MalfunctionSummary.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import Foundation
import SwiftData

@Model
final class MalfunctionSummary {
    var failureToFeed: Int
    var failureToEject: Int
    var stovepipe: Int
    var doubleFeed: Int
    var lightStrike: Int
    var other: Int

    init(
        failureToFeed: Int = 0,
        failureToEject: Int = 0,
        stovepipe: Int = 0,
        doubleFeed: Int = 0,
        lightStrike: Int = 0,
        other: Int = 0
    ) {
        self.failureToFeed = failureToFeed
        self.failureToEject = failureToEject
        self.stovepipe = stovepipe
        self.doubleFeed = doubleFeed
        self.lightStrike = lightStrike
        self.other = other
    }

    var total: Int {
        failureToFeed + failureToEject + stovepipe + doubleFeed + lightStrike + other
    }
}

