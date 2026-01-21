//
//  FirearmAnalyticsScreen.swift
//  RoundCount
//
//  SessionV2-only analytics (via FirearmRun)
//

import SwiftUI
import SwiftData

struct FirearmAnalyticsScreen: View {
    let title: String
    let firearmId: UUID

    @State private var range: AnalyticsTimeRange = .days90

    @State private var totals: TotalsSummary = .init(rounds: 0, durationSeconds: 0, malfunctions: 0)
    @State private var points: [ChartPoint] = []

    // “premium extras”
    @State private var sessionsCount: Int = 0
    @State private var avgRoundsPerSession: Int = 0
    @State private var lastSessionDate: Date? = nil

    // Source of truth: runs for this firearm
    @Query private var runs: [FirearmRun]

    init(title: String, firearmId: UUID) {
        self.title = title
        self.firearmId = firearmId

        self._runs = Query(
            filter: #Predicate<FirearmRun> { $0.firearm.id == firearmId },
            sort: [SortDescriptor(\FirearmRun.startedAt, order: .reverse)]
        )
    }

    var body: some View {
        List {
            rangePickerSection
            heroSection
            trendSection
            footerNote
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { recompute() }
        .onChange(of: range) { _, _ in recompute() }
        .onChange(of: runs.count) { _, _ in recompute() }
        .onChange(of: runs.first?.id) { _, _ in recompute() }
    }

    // MARK: - Sections

    private var rangePickerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Range")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Range", selection: $range) {
                    ForEach(AnalyticsTimeRange.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                .pickerStyle(.segmented)

                Text(rangeSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Overview")
                        .font(.headline)
                    Spacer()
                    Text("\(sessionsCount) session\(sessionsCount == 1 ? "" : "s")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    premiumStatCard(title: "Rounds", value: "\(totals.rounds)", systemImage: "target")

                    premiumStatCard(
                        title: "Range time",
                        value: totals.durationSeconds > 0 ? "\(totals.durationMinutesRounded)m" : "—",
                        systemImage: "timer"
                    )

                    premiumStatCard(
                        title: "Malfunctions",
                        value: totals.malfunctions > 0 ? "\(totals.malfunctions)" : "—",
                        systemImage: "exclamationmark.triangle"
                    )

                    premiumStatCard(
                        title: "MF / 1k",
                        value: totals.rounds > 0 ? String(format: "%.1f", totals.malfunctionsPerK) : "—",
                        systemImage: "waveform.path.ecg"
                    )
                }

                HStack(spacing: 12) {
                    chipMetric(
                        title: "Avg rounds/session",
                        value: sessionsCount > 0 ? "\(avgRoundsPerSession)" : "—",
                        systemImage: "chart.bar"
                    )

                    chipMetric(
                        title: "Last session",
                        value: lastSessionDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—",
                        systemImage: "clock"
                    )
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var trendSection: some View {
        let title = (range == .week || range == .days30) ? "Rounds by day" : "Rounds by week"

        return Section(title) {
            if points.isEmpty {
                ContentUnavailableView(
                    "No data in this range",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Go live to see trends for this firearm.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    SimpleLineChart(points: points)
                        .frame(height: 190)
                        .padding(.vertical, 6)

                    HStack {
                        Text(points.first?.x.formatted(date: .abbreviated, time: .omitted) ?? "")
                        Spacer()
                        Text(points.last?.x.formatted(date: .abbreviated, time: .omitted) ?? "")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var footerNote: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Calculated from live sessions")
                    .font(.footnote.weight(.semibold))
                Text("This view is computed on-device from your live session runs for this firearm.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Components

    private func premiumStatCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding()
        .neonCard(cornerRadius: 16, intensity: 0.35)
    }

    private func chipMetric(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers

    private var rangeSubtitle: String {
        let cal = Calendar.current
        let now = Date()
        let start = range.startDate(reference: now, calendar: cal)
        if let start {
            return "From \(start.formatted(date: .abbreviated, time: .omitted)) to today"
        }
        return "All time"
    }

    private func recompute() {
        let now = Date()
        let cal = Calendar.current
        let start = range.startDate(reference: now, calendar: cal)

        // Filter runs by range (simple loop to keep compiler happy)
        var filtered: [FirearmRun] = []
        filtered.reserveCapacity(runs.count)
        if let start {
            for r in runs where r.startedAt >= start {
                filtered.append(r)
            }
        } else {
            filtered = runs
        }

        // Totals
        var rounds = 0
        var durationSeconds = 0
        var malfunctions = 0

        // Unique sessions
        var sessionIDs: Set<UUID> = []
        sessionIDs.reserveCapacity(filtered.count)

        for r in filtered {
            rounds += r.rounds
            durationSeconds += r.durationSeconds
            malfunctions += r.malfunctionsCount
            sessionIDs.insert(r.session.id)
        }

        totals = TotalsSummary(rounds: rounds, durationSeconds: durationSeconds, malfunctions: malfunctions)
        sessionsCount = sessionIDs.count
        avgRoundsPerSession = sessionsCount > 0 ? Int(round(Double(rounds) / Double(sessionsCount))) : 0

        // Last session date (latest run’s session startedAt)
        lastSessionDate = filtered.first?.session.startedAt

        // Trend buckets
        if range == .week || range == .days30 {
            let buckets = roundsByDay(filtered, calendar: cal)
            points = buckets.map { ChartPoint(x: $0.day, y: Double($0.rounds)) }
        } else {
            let buckets = roundsByWeek(filtered, calendar: cal)
            points = buckets.map { ChartPoint(x: $0.weekStart, y: Double($0.rounds)) }
        }
    }

    private struct DayBucket {
        let day: Date
        let rounds: Int
    }

    private func roundsByDay(_ runs: [FirearmRun], calendar: Calendar) -> [DayBucket] {
        var map: [Date: Int] = [:]
        for r in runs {
            let day = calendar.startOfDay(for: r.startedAt)
            map[day, default: 0] += r.rounds
        }
        return map
            .map { DayBucket(day: $0.key, rounds: $0.value) }
            .sorted { $0.day < $1.day }
    }

    private struct WeekBucket {
        let weekStart: Date
        let rounds: Int
    }

    private func roundsByWeek(_ runs: [FirearmRun], calendar: Calendar) -> [WeekBucket] {
        var map: [Date: Int] = [:]
        for r in runs {
            let day = calendar.startOfDay(for: r.startedAt)
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)
            guard let weekStart = calendar.date(from: comps) else { continue }
            map[weekStart, default: 0] += r.rounds
        }
        return map
            .map { WeekBucket(weekStart: $0.key, rounds: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }
}
