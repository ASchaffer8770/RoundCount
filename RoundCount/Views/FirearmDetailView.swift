//
//  FirearmDetailView.swift
//  RoundCount
//
//  Live-only (SessionV2 / FirearmRun)
//

import SwiftUI
import SwiftData

struct FirearmDetailView: View {
    @Bindable var firearm: Firearm

    // ✅ Runs filtered by firearm (we derive SessionV2 list from run.session)
    @Query private var runsForFirearm: [FirearmRun]

    // ✅ Magazines filtered by firearm (avoids needing firearm.magazines property)
    @Query private var magazinesForFirearm: [FirearmMagazine]

    @EnvironmentObject private var entitlements: Entitlements
    @EnvironmentObject private var tabRouter: AppTabRouter

    @State private var showEdit = false
    @State private var showAddSetup = false
    @State private var showMagazines = false

    // Default = last 30 days
    @State private var range: DashboardDateRange = .days30

    init(firearm: Firearm) {
        self.firearm = firearm

        let firearmId = firearm.id

        self._runsForFirearm = Query(
            filter: #Predicate<FirearmRun> { $0.firearm.id == firearmId },
            sort: [SortDescriptor(\FirearmRun.startedAt, order: .reverse)]
        )

        self._magazinesForFirearm = Query(
            filter: #Predicate<FirearmMagazine> { $0.firearm.id == firearmId },
            sort: [SortDescriptor(\FirearmMagazine.capacity, order: .reverse)]
        )
    }

    // MARK: - Derived

    private var lastUsedText: String {
        guard let d = firearm.lastUsedDate else { return "—" }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    private var magsCount: Int { magazinesForFirearm.count }

    private var rangeStart: Date? { range.startDate(relativeToNow: Date()) }

    /// Unique SessionV2s that include this firearm (via FirearmRun.session)
    private var liveSessionsForFirearm: [SessionV2] {
        var map: [UUID: SessionV2] = [:]
        for run in runsForFirearm {
            let s = run.session // ✅ non-optional
            map[s.id] = s
        }

        var list = Array(map.values)
        list.sort { $0.startedAt > $1.startedAt }

        if let start = rangeStart {
            list = list.filter { $0.startedAt >= start }
        }
        return list
    }

    private var liveSessionsCount: Int { liveSessionsForFirearm.count }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                headerHero
                quickActionsCard
                rangeCard
                gearAndSetupsCard
                liveSessionsCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEdit = true } label: { Image(systemName: "pencil") }
            }
        }
        .navigationDestination(isPresented: $showMagazines) {
            FirearmMagazinesEditorView(firearm: firearm)
        }
        .sheet(isPresented: $showEdit) {
            AddFirearmView(editingFirearm: firearm)
        }
        .sheet(isPresented: $showAddSetup) {
            AddSetupView(firearm: firearm)
        }
    }

    // MARK: - Cards

    private var headerHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(firearm.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Text(firearm.caliber)
                    Text("•")
                    Text(firearm.firearmClass.rawValue)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                StatPill(title: "Total Rounds", value: "\(firearm.totalRounds)")
                StatPill(title: "Live Sessions", value: "\(liveSessionsCount)")
                StatPill(title: "Last Used", value: lastUsedText)
            }
        }
        .padding(14)
        .neonCard(cornerRadius: 18, intensity: 0.28)
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            Button {
                tabRouter.startLive(for: firearm.id)
            } label: {
                HStack {
                    Image(systemName: "timer")
                    Text("Start Live Session")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .buttonStyle(.borderedProminent)

            VStack(spacing: 10) {
                overviewRow("Purchased", firearm.purchaseDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")

                if let sn = firearm.serialNumber, !sn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    overviewRow("Serial", sn)
                }
            }
            .font(.subheadline)
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var rangeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date Range")
                .font(.headline)

            Picker("Range", selection: $range) {
                ForEach(DashboardDateRange.allCases) { r in
                    Text(r.title).tag(r)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var gearAndSetupsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gear & Setups")
                .font(.headline)

            Button {
                showMagazines = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magazine.fill")
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Magazines")
                            .fontWeight(.semibold)
                        Text(magsCount == 0 ? "Add capacities (17, 21, etc.) for fast round logging" : "\(magsCount) saved")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Divider().opacity(0.4)

            if firearm.setups.isEmpty {
                Text("No setups yet.")
                    .foregroundStyle(.secondary)

                Button { showAddSetup = true } label: {
                    Label("Add Setup", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
            } else {
                ForEach(
                    firearm.setups.sorted {
                        if $0.isActive != $1.isActive { return $0.isActive && !$1.isActive }
                        return $0.createdAt > $1.createdAt
                    }
                ) { setup in
                    NavigationLink {
                        SetupDetailView(firearm: firearm, setup: setup)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(setup.name).font(.headline)
                                    if setup.isActive {
                                        Text("Active")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(.thinMaterial)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("\(setup.gear.count) gear item\(setup.gear.count == 1 ? "" : "s")")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }

                Button { showAddSetup = true } label: {
                    Label("Add Setup", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .padding(.top, 6)
            }
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var liveSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Sessions")
                .font(.headline)

            if liveSessionsForFirearm.isEmpty {
                Text("No live sessions in this range.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(liveSessionsForFirearm.prefix(12)) { s in
                        liveSessionRow(s)
                    }
                }
            }
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    // MARK: - Rows

    private func liveSessionRow(_ s: SessionV2) -> some View {
        let rounds = s.totalRounds
        let malfs = s.totalMalfunctions
        let minutes = max(1, s.durationSeconds / 60)

        return Button {
            // ✅ Tap row jumps user into Live tab (lowest friction right now)
            tabRouter.selectedTab = .live
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(rounds) rounds")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(s.startedAt, style: .date)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    if malfs > 0 {
                        Label("\(malfs) malf", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Label("\(minutes)m", systemImage: "timer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let notes = s.notes, !notes.isEmpty {
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

    private func overviewRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Date Range (shared)

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

// MARK: - Small UI helpers

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
