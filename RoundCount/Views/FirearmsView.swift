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
        NavigationStack {
            List {
                Section {
                    if firearms.isEmpty {
                        ContentUnavailableView(
                            "No Firearms",
                            systemImage: "scope",
                            description: Text("Add your first firearm to start tracking sessions.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    } else {
                        ForEach(firearms) { f in
                            NavigationLink {
                                FirearmDetailView(firearm: f)
                            } label: {
                                FirearmRowCard(firearm: f)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    editingFirearm = f
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    requestDelete(f)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    // Keep header minimal; section itself will be in an accentCard container.
                    EmptyView()
                }
                .textCase(nil)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Brand.pageBackground(scheme))
            .navigationTitle("Firearms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
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
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Wrap the list content in a parent accent card look
            .safeAreaInset(edge: .top) {
                // This creates the “parent card” feel without fighting List layout too hard
                Color.clear
                    .frame(height: 0)
            }
            .overlay(alignment: .top) {
                // Subtle parent container wash behind the list rows
                VStack(spacing: 0) {
                    // Title / meta strip could go here later (counts, filters, etc.)
                    Spacer().frame(height: 0)
                }
            }
            .padding(.horizontal, Brand.screenPadding) // makes rows align with Dashboard spacing
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
        // Parent “accent card” framing for the whole screen content
        .background(Brand.pageBackground(scheme))
    }

    // MARK: - Delete (SessionV2 via FirearmRun)

    private func requestDelete(_ firearm: Firearm) {
        firearmPendingDelete = firearm

        let sessionIDs = sessionsInvolvingFirearm(firearmID: firearm.id)
        pendingDeleteSessionCount = sessionIDs.count

        if pendingDeleteSessionCount == 0 {
            modelContext.delete(firearm)
            firearmPendingDelete = nil
            return
        }

        showDeleteConfirm = true
    }

    private func performDelete() {
        guard let firearm = firearmPendingDelete else { return }
        let fid = firearm.id

        // 1) Fetch runs for this firearm
        let runs = fetchRuns(for: fid)

        // 2) Track impacted sessions (so we can delete sessions that become empty)
        var impactedSessionIDs: Set<UUID> = []
        impactedSessionIDs.reserveCapacity(runs.count)
        for run in runs {
            impactedSessionIDs.insert(run.session.id)
        }

        // 3) Delete the runs
        for run in runs {
            modelContext.delete(run)
        }

        // 4) Delete any now-empty sessions
        for sid in impactedSessionIDs {
            if let s = fetchSession(by: sid), s.runs.isEmpty {
                modelContext.delete(s)
            }
        }

        // 5) Delete firearm
        modelContext.delete(firearm)

        firearmPendingDelete = nil
        pendingDeleteSessionCount = 0
    }

    private func sessionsInvolvingFirearm(firearmID: UUID) -> Set<UUID> {
        let runs = fetchRuns(for: firearmID)
        var ids: Set<UUID> = []
        ids.reserveCapacity(runs.count)
        for r in runs {
            ids.insert(r.session.id)
        }
        return ids
    }

    private func fetchRuns(for firearmID: UUID) -> [FirearmRun] {
        let descriptor = FetchDescriptor<FirearmRun>(
            predicate: #Predicate<FirearmRun> { $0.firearm.id == firearmID },
            sortBy: [SortDescriptor(\FirearmRun.startedAt, order: .reverse)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ fetchRuns failed: \(error)")
            return []
        }
    }

    private func fetchSession(by id: UUID) -> SessionV2? {
        let descriptor = FetchDescriptor<SessionV2>(
            predicate: #Predicate<SessionV2> { $0.id == id }
        )
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("❌ fetchSession failed: \(error)")
            return nil
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
}

// MARK: - Row Card

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
