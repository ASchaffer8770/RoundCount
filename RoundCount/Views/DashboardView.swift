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

    // ✅ Present summary without sheet(item:) to avoid compiler blowups
    @State private var showLiveSummary = false
    @State private var selectedLiveSessionID: UUID? = nil

    @Query(sort: \Firearm.createdAt, order: .reverse) private var firearms: [Firearm]
    @Query(sort: \SessionV2.startedAt, order: .reverse) private var liveSessions: [SessionV2]

    // MARK: - Derived (keep these dumb)
    
    private var lastActivitySession: SessionV2? {
        filteredLiveSessions.first
    }

    private func openLastActivity() {
        guard let s = lastActivitySession else { return }
        selectedLiveSessionID = s.id
        showLiveSummary = true
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

    // ✅ resolve selected SessionV2 only when needed
    private var selectedLiveSession: SessionV2? {
        guard let id = selectedLiveSessionID else { return nil }
        // Prefer filtered first (what user sees)
        if let s = filteredLiveSessions.first(where: { $0.id == id }) { return s }
        // Fallback to all sessions (just in case)
        return liveSessions.first(where: { $0.id == id })
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
            // ✅ bool-based sheet = compiler-friendly
            .sheet(isPresented: $showLiveSummary) {
                if let s = selectedLiveSession {
                    LiveSessionSummarySheet(session: s)
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Session not found",
                            systemImage: "timer",
                            description: Text("This session may have been deleted.")
                        )
                        .navigationTitle("Live Session")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showLiveSummary = false }
                            }
                        }
                    }
                }
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

            if lastActivityDate != nil {
                Button {
                    openLastActivity()
                } label: {
                    Text("Last activity: \(lastActivityDateText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(lastActivitySession == nil)
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
                Button {
                    openLastActivity()
                } label: {
                    StatCard(
                        title: "Last activity",
                        value: lastActivityDate?.formatted(date: .abbreviated, time: .omitted) ?? "—",
                        systemImage: "clock"
                    )
                }
                .buttonStyle(.plain)
                .disabled(lastActivitySession == nil)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick actions")
                .font(.headline)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
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
                    } label: {
                        HStack {
                            Image(systemName: "scope")
                            Text("Add firearm")
                            Spacer()
                        }
                        .padding()
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        FirearmsView()
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("View firearms")
                            Spacer()
                        }
                        .padding()
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    gateOpenAnalytics()
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                        Text("Analytics (Pro)")
                        Spacer()
                        if !entitlements.isPro {
                            Image(systemName: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .buttonStyle(.bordered)
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
        Button {
            selectedLiveSessionID = row.id
            showLiveSummary = true
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

// MARK: - Live session summary sheet (compiler-friendly: render from value VMs)

private struct LiveSessionSummarySheet: View {
    private let vm: LiveSessionSummaryVM
    @Environment(\.dismiss) private var dismiss

    init(session: SessionV2) {
        self.vm = LiveSessionSummaryVM(session: session)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    row("Started", vm.startedText)
                    row("Duration", vm.durationText)
                    row("Total rounds", vm.totalRoundsText)
                    row("Total malfunctions", vm.totalMalfunctionsText)
                }

                if let notes = vm.sessionNotes, !notes.isEmpty {
                    Section("Session Notes") {
                        Text(notes)
                    }
                }

                Section("Runs") {
                    if vm.runs.isEmpty {
                        Text("No runs recorded.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.runs) { run in
                            RunSummaryRow(run: run)
                                .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Live Session")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RunSummaryRow: View {
    let run: RunSummaryVM

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(run.firearmName)
                    .font(.headline)
                Spacer()
                Text(run.durationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(run.roundsText, systemImage: "target")
                Label(run.malfunctionsText, systemImage: "exclamationmark.triangle")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let magText = run.magText {
                Text(magText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let notes = run.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !run.malfunctionDetails.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Malfunction details")
                        .font(.footnote.weight(.semibold))

                    ForEach(run.malfunctionDetails) { m in
                        Text("• \(m.label)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Value-type VMs (no SwiftData in the view tree)

private struct LiveSessionSummaryVM {
    let startedText: String
    let durationText: String
    let totalRoundsText: String
    let totalMalfunctionsText: String
    let sessionNotes: String?
    let runs: [RunSummaryVM]

    init(session: SessionV2) {
        startedText = session.startedAt.formatted(date: .abbreviated, time: .shortened)

        let minutes = max(1, session.durationSeconds / 60)
        durationText = "\(minutes)m"

        totalRoundsText = "\(session.totalRounds)"
        totalMalfunctionsText = "\(session.totalMalfunctions)"

        if let notes = session.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !notes.isEmpty {
            sessionNotes = notes
        } else {
            sessionNotes = nil
        }

        // Build run VMs once (sorted)
        let sortedRuns = session.runs.sorted { $0.startedAt < $1.startedAt }
        runs = sortedRuns.map { RunSummaryVM(run: $0) }
    }
}

private struct RunSummaryVM: Identifiable {
    let id: UUID

    let firearmName: String
    let durationText: String
    let roundsText: String
    let malfunctionsText: String

    let magText: String?
    let notes: String?

    let malfunctionDetails: [MalfunctionDetailVM]

    init(run: FirearmRun) {
        id = run.id

        firearmName = run.firearm.displayName

        let minutes = max(1, run.durationSeconds / 60)
        durationText = "\(minutes)m"

        roundsText = "\(run.rounds) rounds"
        malfunctionsText = "\(run.malfunctionsCount) malf"

        if let mag = run.selectedMagazine {
            magText = "Mag: \(mag.capacity) rounds"
        } else {
            magText = nil
        }

        if let n = run.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !n.isEmpty {
            notes = n
        } else {
            notes = nil
        }

        // Snapshot malfunction details
        if run.malfunctions.isEmpty {
            malfunctionDetails = []
        } else {
            malfunctionDetails = run.malfunctions.map { MalfunctionDetailVM(m: $0) }
        }
    }
}

private struct MalfunctionDetailVM: Identifiable {
    let id: UUID
    let label: String

    init(m: RunMalfunction) {
        id = m.id
        // Use shortLabel for dense UI; switch to m.kindRaw if you want full text.
        label = "\(m.kind.shortLabel) (\(m.count))"
        // OR: label = "\(m.kindRaw) (\(m.count))"
    }
}


// MARK: - Small components

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
