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
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var router: AppRouter

    @State private var showPaywall = false
    @State private var paywallFeature: Feature? = nil
    @State private var gateMessage: String? = nil
    @State private var showGateAlert = false
    @State private var showAddFirearm = false

    // ✅ Dashboard range control (default: 30 days)
    @State private var range: DashboardDateRange = .days30

    @Query(sort: \Firearm.createdAt, order: .reverse) private var firearms: [Firearm]
    @Query(sort: \SessionV2.startedAt, order: .reverse) private var liveSessions: [SessionV2]

    // ✅ Source of truth for total rounds (fixes dashboard totals)
    @Query(sort: \FirearmRun.startedAt, order: .reverse) private var allRuns: [FirearmRun]

    // MARK: - Derived

    private var totalFirearms: Int { firearms.count }
    private var rangeStart: Date? { range.startDate }

    private var filteredRuns: [FirearmRun] {
        guard let start = rangeStart else { return allRuns }
        return allRuns.filter { $0.startedAt >= start }
    }

    private var totalRounds: Int {
        filteredRuns.reduce(0) { $0 + $1.rounds }
    }

    private var filteredLiveSessions: [SessionV2] {
        guard let start = rangeStart else { return liveSessions }
        return liveSessions.filter { $0.startedAt >= start }
    }

    private var lastActivitySession: SessionV2? { filteredLiveSessions.first }

    private var lastActivityDateText: String {
        guard let d = lastActivitySession?.startedAt else { return "—" }
        return d.formatted(date: .abbreviated, time: .shortened)
    }

    private var mostUsedFirearm: Firearm? {
        firearms.max(by: { $0.totalRounds < $1.totalRounds })
    }

    private var recentLiveRows: [LiveSessionRowVM] {
        Array(filteredLiveSessions.prefix(8)).map { LiveSessionRowVM(from: $0) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Spacing.l) {
                header
                dateRangePicker
                statsGrid
                quickActions
                analyticsButton
                recentActivity
                Spacer(minLength: 24)
            }
            .padding(Brand.screenPadding)
        }
        .background(Brand.pageBackground(scheme))
        .navigationTitle("RoundCount")

        // Sheets
        .sheet(isPresented: $showAddFirearm) { AddFirearmView() }
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

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.xs) {
            Text("Dashboard")
                .font(.title.bold())

            if let s = lastActivitySession {
                NavigationLink(value: AppRoute.sessionDetail(s.id)) {
                    Text("Last activity: \(lastActivityDateText)")
                        .font(.subheadline)
                        .foregroundStyle(Brand.accent.opacity(scheme == .dark ? 0.85 : 0.75))
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
        VStack(alignment: .leading, spacing: Brand.Spacing.s) {
            Text("Date range")
                .font(Brand.Typography.section)

            Picker("Date range", selection: $range) {
                ForEach(DashboardDateRange.allCases, id: \.self) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.s) {
            Text("Overview")
                .font(Brand.Typography.section)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {

                NavigationLink(value: AppRoute.firearmsIndex) {
                    StatCard(title: "Firearms", value: "\(totalFirearms)", systemImage: "scope")
                }
                .buttonStyle(.plain)

                NavigationLink(value: AppRoute.ammoIndex) {
                    StatCard(title: "Total rounds", value: "\(totalRounds)", systemImage: "target")
                }
                .buttonStyle(.plain)

                if let mf = mostUsedFirearm {
                    NavigationLink(value: AppRoute.firearmDetail(mf.persistentModelID)) {
                        StatCard(title: "Most used", value: mf.displayName, systemImage: "flame")
                    }
                    .buttonStyle(.plain)
                } else {
                    StatCard(title: "Most used", value: "—", systemImage: "flame")
                }

                if let s = lastActivitySession {
                    NavigationLink(value: AppRoute.sessionDetail(s.id)) {
                        StatCard(
                            title: "Last activity",
                            value: s.startedAt.formatted(date: .abbreviated, time: .omitted),
                            systemImage: "clock"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    StatCard(title: "Last activity", value: "—", systemImage: "clock")
                }
            }
        }
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.s) {
            Text("Quick actions")
                .font(Brand.Typography.section)

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

                NavigationLink(value: AppRoute.firearmsIndex) {
                    SquareActionTile(title: "View Firearms", systemImage: "list.bullet")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    private var analyticsButton: some View {
        Button {
            gateOpenAnalytics()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title3.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Analytics")
                        .fontWeight(.semibold)
                    Text(entitlements.isPro ? "Trends, breakdowns, and performance insights" : "Pro feature")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: entitlements.isPro ? "chevron.right" : "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            // ✅ makes the whole card tappable, not just text
            .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.l, style: .continuous))
        }
        .buttonStyle(.plain)
        .accentCard(radius: Brand.Radius.l)
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.s) {
            Text("Recent activity")
                .font(Brand.Typography.section)

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
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    private func liveActivityRow(row: LiveSessionRowVM) -> some View {
        NavigationLink(value: AppRoute.sessionDetail(row.id)) {
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

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let notes = row.notesPreview, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
        }
        .buttonStyle(.plain)
        .surfaceCard(radius: Brand.Radius.m)
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
            router.dashboardPath.append(AppRoute.analyticsDashboard)
            return
        }

        paywallFeature = .advancedAnalytics
        gateMessage = "Analytics is a Pro feature. Upgrade to unlock trends, breakdowns, and performance insights."
        showGateAlert = true
    }
}

// MARK: - Lightweight row VM

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

// MARK: - Buttons + Cards

private struct SquareActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SquareActionTile(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

private struct SquareActionTile: View {
    let title: String
    let systemImage: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Brand.accent.opacity(scheme == .dark ? 0.18 : 0.10))
                    .frame(width: 44, height: 44)

                Circle()
                    .strokeBorder(Brand.accent.opacity(scheme == .dark ? 0.55 : 0.35), lineWidth: 1)
                    .frame(width: 44, height: 44)

                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Brand.accent.opacity(scheme == .dark ? 0.95 : 0.85))
            }

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.2, contentMode: .fit)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .surfaceCard(radius: Brand.Radius.l)
        .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.l, style: .continuous))
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
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .surfaceCard(radius: Brand.Radius.m)
    }
}
