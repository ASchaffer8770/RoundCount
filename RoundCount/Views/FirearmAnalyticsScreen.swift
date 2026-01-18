//
//  FirearmAnalyticsScreen.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/18/26.
//

import SwiftUI

struct FirearmAnalyticsScreen: View {
    let title: String
    let sessions: [SessionSnapshot]

    @State private var range: AnalyticsTimeRange = .days90

    @State private var totals: TotalsSummary = .init(rounds: 0, durationSeconds: 0, malfunctions: 0)
    @State private var weeklyPoints: [ChartPoint] = []
    @State private var topSetups: [TopRow] = []

    // premium extras
    @State private var sessionsCount: Int = 0
    @State private var avgRoundsPerSession: Int = 0
    @State private var lastSessionDate: Date? = nil

    var body: some View {
        List {
            rangePickerSection
            heroSection
            trendSection
            setupSection
            footerNote
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { recompute() }
        .onChange(of: range) { _, _ in recompute() }
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
        Section(range == .days7 || range == .days30 ? "Rounds by day" : "Rounds by week") {
            if weeklyPoints.isEmpty {
                ContentUnavailableView(
                    "No data in this range",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Log sessions to see trends for this firearm.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    SimpleLineChart(points: weeklyPoints)
                        .frame(height: 190)
                        .padding(.vertical, 6)

                    HStack {
                        Text(weeklyPoints.first?.x.formatted(date: .abbreviated, time: .omitted) ?? "")
                        Spacer()
                        Text(weeklyPoints.last?.x.formatted(date: .abbreviated, time: .omitted) ?? "")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var setupSection: some View {
        Section("Setup breakdown") {
            if topSetups.isEmpty {
                Text("Log sessions with a setup to see setup analytics.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topSetups) { row in
                    rankedRow(title: row.title, value: row.value, suffix: "rds")
                }
            }
        }
    }

    private var footerNote: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Calculated from sessions")
                    .font(.footnote.weight(.semibold))
                Text("This view is computed from your logged sessions for this firearm.")
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

    private func rankedRow(title: String, value: Int, suffix: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .lineLimit(1)

                Text("\(value) \(suffix)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .opacity(0.35)
        }
        .padding(.vertical, 6)
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
        let filtered = AnalyticsService.filteredSessions(sessions, range: range)

        totals = AnalyticsService.totals(filtered)
        topSetups = AnalyticsService.topSetupsByRounds(filtered, limit: 8)

        switch range {
        case .days7, .days30:
            let days = AnalyticsService.roundsByDay(filtered)
            weeklyPoints = days.map { ChartPoint(x: $0.day, y: Double($0.rounds)) }

        case .days90, .year1, .all:
            let weeks = AnalyticsService.roundsByWeek(filtered)
            weeklyPoints = weeks.map { ChartPoint(x: $0.startOfWeek, y: Double($0.rounds)) }
        }

        let count = filtered.count
        sessionsCount = count
        avgRoundsPerSession = count > 0 ? Int(round(Double(totals.rounds) / Double(count))) : 0
        lastSessionDate = filtered.first?.date
    }

}
