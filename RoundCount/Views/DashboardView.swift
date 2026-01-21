//
//  DashboardView.swift
//  RoundCount
//
//  Live-only (SessionV2)
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject private var entitlements: Entitlements

    @State private var showPaywall = false
    @State private var paywallFeature: Feature? = nil
    @State private var gateMessage: String? = nil
    @State private var showGateAlert = false
    @State private var showAnalytics = false
    @State private var showAddFirearm = false

    // ✅ Dashboard range control (default: 30 days)
    @State private var range: DashboardDateRange = .days30

    @Query(sort: \Firearm.createdAt, order: .reverse) private var firearms: [Firearm]
    @Query(sort: \SessionV2.startedAt, order: .reverse) private var liveSessions: [SessionV2]

    // MARK: - Derived (keep these dumb)
    
    private var lastActivitySession: SessionV2? {
        filteredLiveSessions.first
    }

    private func openLastActivity() {
        // no-op now because navigation is done via NavigationLink
    }

    private var totalFirearms: Int { firearms.count }

    private var totalRounds: Int {
        firearms.reduce(0) { $0 + $1.totalRounds }
    }

    private var rangeStart: Date? { range.startDate(relativeToNow: Date()) }

    private var filteredLiveSessions: [SessionV2] {
        guard let start = rangeStart else { return liveSessions }
        var out: [SessionV2] = []
        out.reserveCapacity(liveSessions.count)
        for s in liveSessions where s.startedAt >= start {
            out.append(s)
        }
        return out
    }

    private var lastActivityDate: Date? {
        filteredLiveSessions.first?.startedAt
    }

    private var lastActivityDateText: String {
        guard let d = lastActivityDate else { return "—" }
        return d.formatted(date: .abbreviated, time: .shortened)
    }

    private var mostUsedFirearm: Firearm? {
        firearms.max(by: { $0.totalRounds < $1.totalRounds })
    }

    // ✅ lightweight list rows
    private var recentLiveRows: [LiveSessionRowVM] {
        let sessions = Array(filteredLiveSessions.prefix(8))
        var rows: [LiveSessionRowVM] = []
        rows.reserveCapacity(sessions.count)
        for s in sessions {
            rows.append(LiveSessionRowVM(from: s))
        }
        return rows
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    dateRangePicker
                    statsGrid
                    quickActions
                    recentActivity
                    Spacer(minLength: 24)
                }
                .padding()
            }
            .navigationTitle("RoundCount")
            .sheet(isPresented: $showAddFirearm) {
                AddFirearmView()
            }
            .sheet(isPresented: $showAnalytics) {
                NavigationStack { AnalyticsDashboardView() }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(sourceFeature: paywallFeature)
                    .environmentObject(entitlements)
            }
            .alert("Upgrade to Pro", isPresented: $showGateAlert) {
                Button("Not now", role: .cancel) {}
                Button("See Pro") { showPaywall = true }
            } message: {
                Text(gateMessage ?? "This feature requires RoundCount Pro.")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dashboard")
                .font(.title.bold())

            if let s = lastActivitySession {
                NavigationLink {
                    SessionDetailView(sessionID: s.id)
                } label: {
                    Text("Last activity: \(lastActivityDateText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text("Start a Live Session to begin tracking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dateRangePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date range")
                .font(.headline)

            Picker("Date range", selection: $range) {
                ForEach(DashboardDateRange.allCases) { r in
                    Text(r.title).tag(r)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {

                // Firearms -> FirearmsView
                NavigationLink {
                    FirearmsView()
                } label: {
                    StatCard(title: "Firearms", value: "\(totalFirearms)", systemImage: "scope")
                }
                .buttonStyle(.plain)

                // Total rounds -> AmmoView
                NavigationLink {
                    AmmoView()
                } label: {
                    StatCard(title: "Total rounds", value: "\(totalRounds)", systemImage: "target")
                }
                .buttonStyle(.plain)

                // Most used -> FirearmDetailView (if exists)
                if let mf = mostUsedFirearm {
                    NavigationLink {
                        FirearmDetailView(firearm: mf)
                    } label: {
                        StatCard(title: "Most used", value: mf.displayName, systemImage: "flame")
                    }
                    .buttonStyle(.plain)
                } else {
                    StatCard(title: "Most used", value: "—", systemImage: "flame")
                }

                // Last activity -> latest session summary
                if let s = lastActivitySession {
                    NavigationLink {
                        SessionDetailView(sessionID: s.id)
                    } label: {
                        StatCard(
                            title: "Last activity",
                            value: lastActivityDate?.formatted(date: .abbreviated, time: .omitted) ?? "—",
                            systemImage: "clock"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    StatCard(
                        title: "Last activity",
                        value: lastActivityDate?.formatted(date: .abbreviated, time: .omitted) ?? "—",
                        systemImage: "clock"
                    )
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick actions")
                .font(.headline)

            HStack(spacing: 12) {

                SquareActionButton(
                    title: "Add Firearm",
                    systemImage: "scope"
                ) {
                    let result = gateAddFirearm()
                    switch result {
                    case .allowed:
                        showAddFirearm = true
                    case .requiresPro(let feature):
                        paywallFeature = feature
                        showPaywall = true
                    case .limitReached(let feature, let message):
                        gateMessage = message
                        paywallFeature = feature
                        showGateAlert = true
                    }
                }

                NavigationLink {
                    FirearmsView()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.title2)

                        Text("View Firearms")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Gating

    private func gateAddFirearm() -> GateResult {
        if entitlements.isPro { return .allowed }

        if firearms.count >= entitlements.freeFirearmLimit {
            return .limitReached(
                .unlimitedFirearms,
                message: "Free tier is limited to \(entitlements.freeFirearmLimit) firearms. Upgrade to Pro for unlimited firearms."
            )
        }
        return .allowed
    }

    private func gateOpenAnalytics() {
        if entitlements.isPro {
            showAnalytics = true
            return
        }

        paywallFeature = .advancedAnalytics
        gateMessage = "Analytics is a Pro feature. Upgrade to unlock trends, breakdowns, and performance insights."
        showGateAlert = true
    }

    // MARK: - Recent activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent activity")
                .font(.headline)

            if recentLiveRows.isEmpty {
                ContentUnavailableView(
                    "No activity yet",
                    systemImage: "timer",
                    description: Text("Your live sessions will show up here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(recentLiveRows) { row in
                        liveActivityRow(row: row)
                    }
                }
            }
        }
    }

    private func liveActivityRow(row: LiveSessionRowVM) -> some View {
        NavigationLink {
            SessionDetailView(sessionID: row.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(row.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(row.dateText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Label("\(row.rounds) rounds", systemImage: "target")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if row.malfunctions > 0 {
                        Label("\(row.malfunctions) malf", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Label("\(row.minutes)m", systemImage: "timer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                if let notes = row.notesPreview, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lightweight row VM (kills SwiftUI inference issues)

private struct LiveSessionRowVM: Identifiable {
    let id: UUID
    let title: String
    let dateText: String
    let rounds: Int
    let malfunctions: Int
    let minutes: Int
    let notesPreview: String?

    init(from s: SessionV2) {
        id = s.id
        rounds = s.totalRounds
        malfunctions = s.totalMalfunctions
        minutes = max(1, s.durationSeconds / 60)
        dateText = s.startedAt.formatted(date: .abbreviated, time: .omitted)

        if let notes = s.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notesPreview = notes
        } else {
            notesPreview = nil
        }

        // simple title
        var firstName: String? = nil
        var uniqueCount = 0
        var seen: [UUID] = []

        for run in s.runs {
            let fid = run.firearm.id
            if !seen.contains(fid) {
                seen.append(fid)
                uniqueCount += 1
                if uniqueCount == 1 { firstName = run.firearm.displayName }
                if uniqueCount > 1 { break }
            }
        }

        if uniqueCount == 1, let name = firstName {
            title = "Live • \(name)"
        } else if uniqueCount > 1 {
            title = "Live • \(uniqueCount) firearms"
        } else {
            title = "Live • Session"
        }
    }
}

// MARK: - Date Range

private enum DashboardDateRange: String, CaseIterable, Identifiable {
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

    func startDate(relativeToNow now: Date) -> Date? {
        let cal = Calendar.current
        switch self {
        case .week:
            return cal.date(byAdding: .day, value: -7, to: now)
        case .days30:
            return cal.date(byAdding: .day, value: -30, to: now)
        case .days90:
            return cal.date(byAdding: .day, value: -90, to: now)
        case .ytd:
            let year = cal.component(.year, from: now)
            return cal.date(from: DateComponents(year: year, month: 1, day: 1))
        case .all:
            return nil
        }
    }
}

// MARK: - Small components

private struct SquareActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
