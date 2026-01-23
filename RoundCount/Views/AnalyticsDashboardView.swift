import SwiftUI
import SwiftData
import Charts

struct AnalyticsDashboardView: View {
    @EnvironmentObject private var entitlements: Entitlements
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\SessionV2.startedAt, order: .reverse)])
    private var allSessions: [SessionV2]

    @State private var range: AnalyticsTimeRange = .days30

    @State private var totals = TotalsSummary(rounds: 0, durationSeconds: 0, malfunctions: 0)
    @State private var weekly: [RoundsBucket] = []
    @State private var topFirearms: [TopRow] = []

    @State private var sessionsCount = 0
    @State private var avgRoundsPerSession = 0
    @State private var lastSessionDate: Date? = nil

    var body: some View {
        Group {
            if entitlements.isPro {
                content
            } else {
                PaywallView(sourceFeature: .advancedAnalytics)
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // If this is pushed in a NavigationStack, "Close" will pop.
            // If it's ever presented modally, it will dismiss the sheet.
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear { recompute() }
        .onChange(of: range) { _, _ in recompute() }
        .onChange(of: allSessions.count) { _, _ in recompute() }
    }

    private var content: some View {
        List {
            rangePicker
            overview
            chart
            topFirearmsSection
        }
    }

    // MARK: Sections

    private var rangePicker: some View {
        Section {
            Picker("Range", selection: $range) {
                ForEach(AnalyticsTimeRange.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var overview: some View {
        Section("Overview") {
            Text("Sessions: \(sessionsCount)")
            Text("Rounds: \(totals.rounds)")
            Text("Time: \(totals.durationMinutesRounded)m")
            Text("Malfunctions: \(totals.malfunctions)")
            Text("Avg / session: \(avgRoundsPerSession)")
        }
    }

    private var chart: some View {
        Section("Rounds over time") {
            if weekly.isEmpty {
                ContentUnavailableView(
                    "No data",
                    systemImage: "chart.bar",
                    description: Text("Log a Live Session to see analytics.")
                )
                .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(weekly) { b in
                        BarMark(
                            x: .value("Week", b.startOfWeek, unit: .weekOfYear),
                            y: .value("Rounds", b.rounds)
                        )
                    }
                }
                .frame(height: 200)
            }
        }
    }

    private var topFirearmsSection: some View {
        Section("Top Firearms") {
            if topFirearms.isEmpty {
                Text("No data")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topFirearms) { row in
                    HStack {
                        Text(row.title)
                        Spacer()
                        Text("\(row.value) rds")
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: Logic

    private func recompute() {
        let filtered = AnalyticsService.filteredSessions(allSessions, range: range)

        totals = AnalyticsService.totals(filtered)
        weekly = AnalyticsService.roundsByWeek(filtered)
        topFirearms = AnalyticsService.topFirearmsByRounds(filtered)

        sessionsCount = filtered.count
        avgRoundsPerSession = sessionsCount > 0 ? (totals.rounds / sessionsCount) : 0
        lastSessionDate = filtered.first?.startedAt
    }
}
