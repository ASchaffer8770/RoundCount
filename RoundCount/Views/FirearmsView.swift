//
//  FirearmsView.swift
//  RoundCount
//
//  Styled with Brand surface system:
//  - Parent cards: .accentCard()
//  - Inner cards:  .surfaceCard()
//

import SwiftUI
import SwiftData

struct FirearmsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var entitlements: Entitlements
    @EnvironmentObject private var router: AppRouter

    @Query(sort: \Firearm.createdAt, order: .reverse)
    private var firearms: [Firearm]

    @State private var showAdd = false
    @State private var editingFirearm: Firearm? = nil

    // Delete confirmation state
    @State private var firearmPendingDelete: Firearm? = nil
    @State private var pendingDeleteSessionCount: Int = 0
    @State private var showDeleteConfirm = false

    // Pro gating
    @State private var showPaywall = false
    @State private var paywallFeature: Feature? = nil
    @State private var gateMessage: String? = nil
    @State private var showGateAlert = false

    var body: some View {
        List {
            headerSection
            listSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Brand.pageBackground(scheme))
        .navigationTitle("Firearms")

        // Sheets / Alerts
        .sheet(isPresented: $showAdd) { AddFirearmView() }
        .sheet(item: $editingFirearm) { f in
            AddFirearmView(editingFirearm: f)
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
        .alert(
            pendingDeleteSessionCount > 0 ? "Delete firearm and sessions?" : "Delete firearm?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            if pendingDeleteSessionCount > 0 {
                Text("This firearm is used in \(pendingDeleteSessionCount) session(s). Deleting it will remove its runs, and any sessions that become empty will also be removed.")
            } else {
                Text("This action can’t be undone.")
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            firearmsHeaderCard
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var listSection: some View {
        Section {
            if firearms.isEmpty {
                emptyStateCard
            } else {
                firearmsListCards
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.s) {
            ContentUnavailableView(
                "No Firearms",
                systemImage: "scope",
                description: Text("Add your first firearm to start tracking sessions.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            Button { openAddFirearm() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Firearm")
                        .font(.headline)
                    Spacer()
                }
                .padding(12)
                .surfaceCard(radius: Brand.Radius.m)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    // MARK: - Firearms List (each firearm is its own card)

    private var firearmsListCards: some View {
        VStack(spacing: 12) {
            ForEach(firearms) { f in
                firearmCard(f)
            }
        }
    }

    private func firearmCard(_ f: Firearm) -> some View {
        // IMPORTANT:
        // Do NOT use NavigationLink inside List rows here, or the system will add
        // its own disclosure chevron. We push via router to keep ONE chevron.
        Button {
            router.firearmsPath.append(.firearmDetail(f.persistentModelID))
        } label: {
            FirearmRowCard(firearm: f)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { editingFirearm = f } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)

            Button(role: .destructive) { requestDelete(f) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    // MARK: - Header card

    private var firearmsHeaderCard: some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Firearms library")
                    .font(Brand.Typography.section)

                Spacer()

                Text("\(firearms.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text("Add the firearms you shoot so Live sessions can attribute rounds, time, and malfunctions correctly.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button { openAddFirearm() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.semibold))
                        Text("Add Firearm")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Brand.accent.opacity(scheme == .dark ? 0.18 : 0.12)))
                    .overlay(
                        Capsule().strokeBorder(Brand.accent.opacity(scheme == .dark ? 0.35 : 0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    // MARK: - Gating

    private func openAddFirearm() {
        let result = gateAddFirearm()
        switch result {
        case .allowed:
            showAdd = true
        case .requiresPro(let feature):
            paywallFeature = feature
            showPaywall = true
        case .limitReached(let feature, let message):
            gateMessage = message
            paywallFeature = feature
            showGateAlert = true
        }
    }

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

    // MARK: - Delete (SessionV2 via FirearmRun)

    private func requestDelete(_ firearm: Firearm) {
        firearmPendingDelete = firearm

        let sessionIDs = sessionsInvolvingFirearm(firearmID: firearm.id)
        pendingDeleteSessionCount = sessionIDs.count

        if pendingDeleteSessionCount == 0 {
            modelContext.delete(firearm)
            try? modelContext.save()
            firearmPendingDelete = nil
            return
        }

        showDeleteConfirm = true
    }

    private func performDelete() {
        guard let firearm = firearmPendingDelete else { return }
        let fid = firearm.id

        let runs = fetchRuns(for: fid)

        var impactedSessionIDs: Set<UUID> = []
        impactedSessionIDs.reserveCapacity(runs.count)
        for run in runs { impactedSessionIDs.insert(run.session.id) }

        for run in runs { modelContext.delete(run) }

        for sid in impactedSessionIDs {
            if let s = fetchSession(by: sid), s.runs.isEmpty {
                modelContext.delete(s)
            }
        }

        modelContext.delete(firearm)
        try? modelContext.save()

        firearmPendingDelete = nil
        pendingDeleteSessionCount = 0
    }

    private func sessionsInvolvingFirearm(firearmID: UUID) -> Set<UUID> {
        let runs = fetchRuns(for: firearmID)
        var ids: Set<UUID> = []
        ids.reserveCapacity(runs.count)
        for r in runs { ids.insert(r.session.id) }
        return ids
    }

    private func fetchRuns(for firearmID: UUID) -> [FirearmRun] {
        let descriptor = FetchDescriptor<FirearmRun>(
            predicate: #Predicate<FirearmRun> { $0.firearm.id == firearmID },
            sortBy: [SortDescriptor(\FirearmRun.startedAt, order: .reverse)]
        )
        do { return try modelContext.fetch(descriptor) }
        catch {
            print("❌ fetchRuns failed: \(error)")
            return []
        }
    }

    private func fetchSession(by id: UUID) -> SessionV2? {
        let descriptor = FetchDescriptor<SessionV2>(
            predicate: #Predicate<SessionV2> { $0.id == id }
        )
        do { return try modelContext.fetch(descriptor).first }
        catch {
            print("❌ fetchSession failed: \(error)")
            return nil
        }
    }
}

// MARK: - Row Card (pure UI, ONE chevron)

private struct FirearmRowCard: View {
    let firearm: Firearm
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Brand.accent.opacity(scheme == .dark ? 0.18 : 0.10))
                    .frame(width: 44, height: 44)

                Circle()
                    .strokeBorder(Brand.hairlineAccent(scheme), lineWidth: 1)
                    .frame(width: 44, height: 44)

                Image(systemName: "scope")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Brand.iconAccent(scheme))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(firearm.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(firearm.caliber) • \(firearm.firearmClass.rawValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let last = firearm.lastUsedDate {
                    Text("Last used: \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .surfaceCard(radius: Brand.Radius.l)
        .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.l, style: .continuous))
    }
}
