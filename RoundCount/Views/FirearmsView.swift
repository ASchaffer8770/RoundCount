import SwiftUI
import SwiftData

struct FirearmsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Firearm.createdAt, order: .reverse) private var firearms: [Firearm]
    @Query private var sessions: [Session]

    @State private var showAdd = false
    @State private var editingFirearm: Firearm? = nil

    // Delete confirmation state
    @State private var firearmPendingDelete: Firearm? = nil
    @State private var pendingDeleteSessionCount: Int = 0
    @State private var showDeleteConfirm = false
    
    @EnvironmentObject private var entitlements: Entitlements
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
                Button("See Pro") {
                    showPaywall = true
                }
            } message: {
                Text(gateMessage ?? "This feature requires RoundCount Pro.")
            }
            .alert(
                pendingDeleteSessionCount > 0
                ? "Delete firearm and sessions?"
                : "Delete firearm?",
                isPresented: $showDeleteConfirm
            ) {
                Button("Cancel", role: .cancel) {}

                Button("Delete", role: .destructive) {
                    performDelete()
                }
            } message: {
                if pendingDeleteSessionCount > 0 {
                    Text("This firearm has \(pendingDeleteSessionCount) session(s). Deleting it will also remove those sessions.")
                } else {
                    Text("This action can’t be undone.")
                }
            }
        }
    }

    private func requestDelete(_ firearm: Firearm) {
        firearmPendingDelete = firearm

        // Count sessions tied to this firearm
        let fid = firearm.id
        pendingDeleteSessionCount = sessions.reduce(0) { count, s in
            count + (s.firearm.id == fid ? 1 : 0)
        }

        // If no sessions, delete immediately. Otherwise confirm.
        if pendingDeleteSessionCount == 0 {
            modelContext.delete(firearm)
            firearmPendingDelete = nil
            return
        }

        showDeleteConfirm = true
    }

    private func performDelete() {
        guard let firearm = firearmPendingDelete else { return }

        // Delete sessions first (so we don’t leave orphaned rows)
        let fid = firearm.id
        for s in sessions where s.firearm.id == fid {
            modelContext.delete(s)
        }

        // Delete firearm
        modelContext.delete(firearm)

        firearmPendingDelete = nil
        pendingDeleteSessionCount = 0
    }
    
    private func gateAddFirearm() -> GateResult {
        if entitlements.isPro { return .allowed }

        // Free tier limit
        if firearms.count >= entitlements.freeFirearmLimit {
            return .limitReached(
                .unlimitedFirearms,
                message: "Free tier is limited to \(entitlements.freeFirearmLimit) firearms. Upgrade to Pro for unlimited firearms."
            )
        }

        return .allowed
    }

}
