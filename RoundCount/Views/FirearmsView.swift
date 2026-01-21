import SwiftUI
import SwiftData

struct FirearmsView: View {
    @Environment(\.modelContext) private var modelContext
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
                if firearms.isEmpty {
                    ContentUnavailableView(
                        "No Firearms",
                        systemImage: "scope",
                        description: Text("Add your first firearm to start tracking sessions.")
                    )
                } else {
                    ForEach(firearms) { f in
                        NavigationLink(destination: FirearmDetailView(firearm: f)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.displayName)
                                    .font(.headline)

                                Text("\(f.caliber) • \(f.firearmClass.rawValue)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                if let last = f.lastUsedDate {
                                    Text("Last used: \(last.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
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
            }
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
            .sheet(isPresented: $showAdd) {
                AddFirearmView()
            }
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
