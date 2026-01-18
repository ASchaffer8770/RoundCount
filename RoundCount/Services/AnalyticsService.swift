//
//  AnalyticsService.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/17/26.
//

import Foundation

struct RoundsBucket: Identifiable, Equatable {
    let startOfWeek: Date
    let rounds: Int
    var id: Date { startOfWeek }
}

struct TotalsSummary: Hashable {
    let rounds: Int
    let durationSeconds: Int
    let malfunctions: Int

    var durationMinutesRounded: Int {
        max(0, Int(round(Double(durationSeconds) / 60.0)))
    }

    var malfunctionsPerK: Double {
        guard rounds > 0 else { return 0 }
        return (Double(malfunctions) / Double(rounds)) * 1000.0
    }
}

struct TopRow: Identifiable, Hashable {
    let id: UUID
    let title: String
    let value: Int
}

enum AnalyticsService {

    // MARK: - SwiftData Sessions

    static func filteredSessions(
        _ sessions: [Session],
        range: AnalyticsTimeRange,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> [Session] {
        guard let start = range.startDate(reference: reference, calendar: calendar) else { return sessions }
        return sessions.filter { $0.date >= start }
    }

    static func totals(_ sessions: [Session]) -> TotalsSummary {
        let rounds = sessions.reduce(0) { $0 + $1.rounds }
        let durationSeconds = sessions.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
        let malfunctions = sessions.reduce(0) { $0 + ($1.malfunctions?.total ?? 0) }
        return TotalsSummary(rounds: rounds, durationSeconds: durationSeconds, malfunctions: malfunctions)
    }

    static func roundsByWeek(_ sessions: [Session], calendar: Calendar = .current) -> [RoundsBucket] {
        var map: [Date: Int] = [:]

        for s in sessions {
            let startOfDay = calendar.startOfDay(for: s.date)
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)
            guard let weekStart = calendar.date(from: comps) else { continue }
            map[weekStart, default: 0] += s.rounds
        }

        return map
            .map { RoundsBucket(startOfWeek: $0.key, rounds: $0.value) }
            .sorted { $0.startOfWeek < $1.startOfWeek }
    }

    static func topSetupsByRounds(_ sessions: [Session], limit: Int = 5) -> [TopRow] {
        var map: [UUID: (title: String, value: Int)] = [:]

        for s in sessions {
            guard let setup = s.setup else { continue }
            map[setup.id, default: (setup.name, 0)].value += s.rounds
        }

        return map
            .map { TopRow(id: $0.key, title: $0.value.title, value: $0.value.value) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0 }
    }

    static func topAmmoByRounds(_ sessions: [Session], limit: Int = 5) -> [TopRow] {
        var map: [UUID: (title: String, value: Int)] = [:]

        for s in sessions {
            guard let ammo = s.ammo else { continue }
            map[ammo.id, default: (ammo.displayName, 0)].value += s.rounds
        }

        return map
            .map { TopRow(id: $0.key, title: $0.value.title, value: $0.value.value) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Snapshot Sessions (value types)

extension AnalyticsService {

    static func filteredSessions(
        _ sessions: [SessionSnapshot],
        range: AnalyticsTimeRange,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> [SessionSnapshot] {
        guard let start = range.startDate(reference: reference, calendar: calendar) else { return sessions }
        return sessions.filter { $0.date >= start }
    }

    static func totals(_ sessions: [SessionSnapshot]) -> TotalsSummary {
        let rounds = sessions.reduce(0) { $0 + $1.rounds }
        let durationSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        let malfunctions = sessions.reduce(0) { $0 + $1.malfunctionsTotal }
        return TotalsSummary(rounds: rounds, durationSeconds: durationSeconds, malfunctions: malfunctions)
    }

    static func roundsByWeek(_ sessions: [SessionSnapshot], calendar: Calendar = .current) -> [RoundsBucket] {
        var map: [Date: Int] = [:]

        for s in sessions {
            let startOfDay = calendar.startOfDay(for: s.date)
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)
            guard let weekStart = calendar.date(from: comps) else { continue }
            map[weekStart, default: 0] += s.rounds
        }

        return map
            .map { RoundsBucket(startOfWeek: $0.key, rounds: $0.value) }
            .sorted { $0.startOfWeek < $1.startOfWeek }
    }

    static func topSetupsByRounds(_ sessions: [SessionSnapshot], limit: Int = 5) -> [TopRow] {
        var map: [UUID: (title: String, value: Int)] = [:]

        for s in sessions {
            guard let id = s.setupId else { continue }
            let title = s.setupName ?? "Setup"
            map[id, default: (title, 0)].value += s.rounds
        }

        return map
            .map { TopRow(id: $0.key, title: $0.value.title, value: $0.value.value) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0 }
    }

    static func topAmmoByRounds(_ sessions: [SessionSnapshot], limit: Int = 5) -> [TopRow] {
        // NOTE: Only keep this if SessionSnapshot actually has ammoId/ammoName.
        // If it doesn't, delete this entire function (and any callers).
        var map: [UUID: (title: String, value: Int)] = [:]

        for s in sessions {
            guard let id = s.ammoId else { continue }
            let title = s.ammoName ?? "Ammo"
            map[id, default: (title, 0)].value += s.rounds
        }

        return map
            .map { TopRow(id: $0.key, title: $0.value.title, value: $0.value.value) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Daily buckets (Snapshot)

    struct DayBucket: Identifiable, Equatable {
        let day: Date          // start-of-day
        let rounds: Int
        var id: Date { day }
    }

    static func roundsByDay(_ sessions: [SessionSnapshot], calendar: Calendar = .current) -> [DayBucket] {
        var map: [Date: Int] = [:]

        for s in sessions {
            let day = calendar.startOfDay(for: s.date)
            map[day, default: 0] += s.rounds
        }

        return map
            .map { DayBucket(day: $0.key, rounds: $0.value) }
            .sorted { $0.day < $1.day }
    }
}
