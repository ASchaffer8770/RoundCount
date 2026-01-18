//
//  AnalyticsTimeRange.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/17/26.
//

import Foundation

enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case days7, days30, days90, year1, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days7: return "7D"
        case .days30: return "30D"
        case .days90: return "90D"
        case .year1: return "1Y"
        case .all: return "All"
        }
    }

    func startDate(reference: Date = .now, calendar: Calendar = .current) -> Date? {
        let startOfToday = calendar.startOfDay(for: reference)
        switch self {
        case .days7:
            return calendar.date(byAdding: .day, value: -6, to: startOfToday)
        case .days30:
            return calendar.date(byAdding: .day, value: -29, to: startOfToday)
        case .days90:
            return calendar.date(byAdding: .day, value: -89, to: startOfToday)
        case .year1:
            return calendar.date(byAdding: .year, value: -1, to: startOfToday)
        case .all:
            return nil
        }
    }
}

