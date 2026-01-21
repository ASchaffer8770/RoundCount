//
//  AnalyticsTimeRange.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/17/26.
//

import Foundation

enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case week
    case days30
    case days90
    case ytd
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "1W"
        case .days30: return "30D"
        case .days90: return "90D"
        case .ytd: return "YTD"
        case .all: return "All"
        }
    }

    func startDate(reference: Date = .now, calendar: Calendar = .current) -> Date? {
        let startOfToday = calendar.startOfDay(for: reference)

        switch self {
        case .week:
            // inclusive 7-day window: today + previous 6 days
            return calendar.date(byAdding: .day, value: -6, to: startOfToday)

        case .days30:
            return calendar.date(byAdding: .day, value: -29, to: startOfToday)

        case .days90:
            return calendar.date(byAdding: .day, value: -89, to: startOfToday)

        case .ytd:
            let year = calendar.component(.year, from: startOfToday)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1))

        case .all:
            return nil
        }
    }
}
