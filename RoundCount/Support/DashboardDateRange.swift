//
//  DashboardDateRange.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

import Foundation

enum DashboardDateRange: String, CaseIterable, Hashable {
    case days7, days30, days90, all

    var label: String {
        switch self {
        case .days7:  return "7 Days"
        case .days30: return "30 Days"
        case .days90: return "90 Days"
        case .all:    return "All Time"
        }
    }

    var startDate: Date? {
        let cal = Calendar.current
        switch self {
        case .days7:  return cal.date(byAdding: .day, value: -7, to: .now)
        case .days30: return cal.date(byAdding: .day, value: -30, to: .now)
        case .days90: return cal.date(byAdding: .day, value: -90, to: .now)
        case .all:    return nil
        }
    }
}

