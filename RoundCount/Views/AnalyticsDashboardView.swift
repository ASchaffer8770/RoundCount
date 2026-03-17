import SwiftUI
import SwiftData
import Charts

struct AnalyticsDashboardView: View {
    @EnvironmentObject private var entitlements: Entitlements
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\SessionV2.startedAt, order: .reverse)])
    private var allSessions: [SessionV2]

    @State private var range: AnalyticsTimeRange = .days30

    // MARK: - Derived
    // Computed directly from @Query + range so they update whenever any session
    // or run changes — not just when the session count changes.

    private var filtered: [SessionV2] {
        AnalyticsService.filteredSessions(allSessions, range: range)
    }

    private var totals: TotalsSummary {
        AnalyticsService.totals(filtered)
    }

    private var weekly: [RoundsBucket] {
        AnalyticsService.roundsByWeek(filtered)
    }

    private var topFirearms: [TopRow] {
        AnalyticsService.topFirearmsByRounds(filtered)
    }

    private var sessionsCount: Int { filtered.count }

    private var avgRoundsPerSession: Int {
        sessionsCount > 0 ? totals.rounds / sessionsCount : 0
    }

    var body: some View {
        Group {
            if entitlements.isPro {
                content
            } else {
                PayWallView(
                    title: "RoundCount Pro",
                    subtitle: "Advanced analytics are a Pro feature."
                )
                .environmentObject(entitlements)
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
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

}
