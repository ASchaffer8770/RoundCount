//
//  AnalyticsService.swift
//  RoundCount
//
//  SessionV2-only analytics
//

import Foundation

// MARK: - Shared Models (single source of truth)

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

// MARK: - Analytics Engine

enum AnalyticsService {

    // MARK: Filtering

    static func filteredSessions(
        _ sessions: [SessionV2],
        range: AnalyticsTimeRange,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> [SessionV2] {
        guard let start = range.startDate(reference: reference, calendar: calendar) else {
            return sessions
        }

        var result: [SessionV2] = []
        result.reserveCapacity(sessions.count)

        for s in sessions where s.startedAt >= start {
            result.append(s)
        }

        return result
    }

    // MARK: Totals

    static func totals(_ sessions: [SessionV2]) -> TotalsSummary {
        var rounds = 0
        var duration = 0
        var malfunctions = 0

        for s in sessions {
            rounds += s.totalRounds
            duration += s.durationSeconds
            malfunctions += s.totalMalfunctions
        }

        return TotalsSummary(
            rounds: rounds,
            durationSeconds: duration,
            malfunctions: malfunctions
        )
    }

    // MARK: Buckets

    static func roundsByWeek(
        _ sessions: [SessionV2],
        calendar: Calendar = .current
    ) -> [RoundsBucket] {

        var map: [Date: Int] = [:]

        for s in sessions {
            let day = calendar.startOfDay(for: s.startedAt)
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)
            guard let weekStart = calendar.date(from: comps) else { continue }
            map[weekStart, default: 0] += s.totalRounds
        }

        return map
            .map { RoundsBucket(startOfWeek: $0.key, rounds: $0.value) }
            .sorted { $0.startOfWeek < $1.startOfWeek }
    }

    // MARK: Top Firearms

    static func topFirearmsByRounds(
        _ sessions: [SessionV2],
        limit: Int = 5
    ) -> [TopRow] {

        var map: [UUID: (String, Int)] = [:]

        for s in sessions {
            for run in s.runs {
                let id = run.firearm.id
                let name = run.firearm.displayName
                map[id, default: (name, 0)].1 += run.rounds
            }
        }

        return map
            .map { TopRow(id: $0.key, title: $0.value.0, value: $0.value.1) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Optional Day Buckets (7D / 30D)

extension AnalyticsService {

    struct DayBucket: Identifiable, Equatable {
        let day: Date
        let rounds: Int
        var id: Date { day }
    }

    static func roundsByDay(
        _ sessions: [SessionV2],
        calendar: Calendar = .current
    ) -> [DayBucket] {

        var map: [Date: Int] = [:]

        for s in sessions {
            let day = calendar.startOfDay(for: s.startedAt)
            map[day, default: 0] += s.totalRounds
        }

        return map
            .map { DayBucket(day: $0.key, rounds: $0.value) }
            .sorted { $0.day < $1.day }
    }
}
