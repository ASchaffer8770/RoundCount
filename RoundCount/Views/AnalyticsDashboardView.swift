import SwiftUI
import SwiftData
import Charts

struct AnalyticsDashboardView: View {
    @EnvironmentObject private var entitlements: Entitlements
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Session.date, order: .reverse)])
    private var allSessions: [Session]

    @State private var range: AnalyticsTimeRange = .days30

    // Cached results
    @State private var totals: TotalsSummary = .init(rounds: 0, durationSeconds: 0, malfunctions: 0)
    @State private var weekly: [RoundsBucket] = []
    @State private var topSetups: [TopRow] = []
    @State private var topAmmo: [TopRow] = []

    // Extra derived metrics (premium feel)
    @State private var sessionsCount: Int = 0
    @State private var avgRoundsPerSession: Int = 0
    @State private var lastSessionDate: Date? = nil

    var body: some View {
        NavigationStack {
            Group {
                if entitlements.isPro {
                    content
                } else {
                    PaywallView(sourceFeature: .advancedAnalytics)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { recompute() }
            .onChange(of: range) { _, _ in recompute() }
            .onChange(of: allSessions.count) { _, _ in recompute() }
            .onChange(of: allSessions.first?.id) { _, _ in recompute() }
        }
    }

    private var content: some View {
        List {
            rangePickerSection

            heroSection

            chartSection

            topSetupsSection

            topAmmoSection

            footerNote
        }
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

                // Premium stat grid (2x2)
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {

                    premiumStatCard(
                        title: "Rounds",
                        value: "\(totals.rounds)",
                        systemImage: "target"
                    )

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

                // Secondary metrics row (adds “pro-ness”)
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

    private var chartSection: some View {
        Section("Rounds over time") {
            if weekly.isEmpty {
                ContentUnavailableView(
                    "No data in this range",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Log sessions to see trends and breakdowns.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Chart {
                        ForEach(weekly) { b in
                            BarMark(
                                x: .value("Week", b.startOfWeek, unit: .weekOfYear),
                                y: .value("Rounds", b.rounds)
                            )
                        }

                        // Average line gives the chart “premium utility”
                        if weekly.count >= 2 {
                            RuleMark(y: .value("Average", averageWeeklyRounds))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .annotation(position: .topLeading) {
                                    Text("Avg \(Int(averageWeeklyRounds))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month().day(), centered: true)
                        }
                    }

                    // Range bounds label (helps users trust the data)
                    HStack {
                        Text(weekly.first?.startOfWeek.formatted(date: .abbreviated, time: .omitted) ?? "")
                        Spacer()
                        Text(weekly.last?.startOfWeek.formatted(date: .abbreviated, time: .omitted) ?? "")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var topSetupsSection: some View {
        Section("Top setups") {
            if topSetups.isEmpty {
                Text("Log sessions with a setup to populate this.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topSetups) { row in
                    rankedRow(
                        title: row.title,
                        value: row.value,
                        suffix: "rds"
                    )
                }
            }
        }
    }

    private var topAmmoSection: some View {
        Section("Top ammo") {
            if topAmmo.isEmpty {
                Text("Select ammo when logging to populate this.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topAmmo) { row in
                    rankedRow(
                        title: row.title,
                        value: row.value,
                        suffix: "rds"
                    )
                }
            }
        }
    }

    private var footerNote: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Local-first analytics")
                    .font(.footnote.weight(.semibold))
                Text("All stats are calculated on-device from your logged sessions.")
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

            // subtle chevron-ish affordance without being a NavigationLink
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .opacity(0.35)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private var rangeSubtitle: String {
        // optional “trust” detail: shows exact inclusive start for selected range
        let cal = Calendar.current
        let now = Date()
        let start = range.startDate(reference: now, calendar: cal)
        if let start {
            return "From \(start.formatted(date: .abbreviated, time: .omitted)) to today"
        }
        return "All time"
    }

    private var averageWeeklyRounds: Double {
        guard !weekly.isEmpty else { return 0 }
        let total = weekly.reduce(0) { $0 + $1.rounds }
        return Double(total) / Double(weekly.count)
    }

    private func recompute() {
        let filtered = AnalyticsService.filteredSessions(allSessions, range: range)

        let newTotals = AnalyticsService.totals(filtered)
        let newWeekly = AnalyticsService.roundsByWeek(filtered)
        let newTopSetups = AnalyticsService.topSetupsByRounds(filtered, limit: 5)
        let newTopAmmo = AnalyticsService.topAmmoByRounds(filtered, limit: 5)

        // Extra derived metrics (from filtered data)
        let newSessionsCount = filtered.count
        let newAvg = newSessionsCount > 0 ? Int(round(Double(newTotals.rounds) / Double(newSessionsCount))) : 0
        let newLast = filtered.first?.date

        if newTotals != totals { totals = newTotals }
        if newWeekly != weekly { weekly = newWeekly }
        if newTopSetups != topSetups { topSetups = newTopSetups }
        if newTopAmmo != topAmmo { topAmmo = newTopAmmo }

        if newSessionsCount != sessionsCount { sessionsCount = newSessionsCount }
        if newAvg != avgRoundsPerSession { avgRoundsPerSession = newAvg }
        if newLast != lastSessionDate { lastSessionDate = newLast }
    }
}
