//
//  ChartPoint.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/18/26.
//

import Foundation

struct ChartPoint: Identifiable, Equatable {
    let x: Date
    let y: Double
    var id: Date { x }
}
