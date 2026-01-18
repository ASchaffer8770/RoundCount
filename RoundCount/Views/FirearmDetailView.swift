//
//  FirearmDetailView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI
import SwiftData

struct FirearmDetailView: View {
    let firearm: Firearm

    @Query private var sessions: [Session]

    @EnvironmentObject private var entitlements: Entitlements

    @State private var showEdit = false
    @State private var showLog = false
    @State private var showAddSetup = false
    @State private var analyticsPayload: [SessionSnapshot] = []

    // Analytics nav + paywall
    @State private var showFirearmAnalytics = false
    @State private var showAnalyticsPaywall = false

    init(firearm: Firearm) {
        self.firearm = firearm

        let firearmId = firearm.id
        self._sessions = Query(
            filter: #Predicate<Session> { $0.firearm.id == firearmId },
            sort: [SortDescriptor(\Session.date, order: .reverse)]
        )
    }

    var body: some View {
        content
            // ✅ Attach these OUTSIDE the List (non-lazy container)
            .navigationDestination(isPresented: $showFirearmAnalytics) {
                FirearmAnalyticsScreen(
                    title: firearm.displayName,
                    sessions: analyticsPayload
                )
            }
            .sheet(isPresented: $showAnalyticsPaywall) {
                PaywallView(sourceFeature: .advancedAnalytics)
                    .environmentObject(entitlements)
            }
            .sheet(isPresented: $showLog) {
                LogSessionView(preselectedFirearm: firearm, isModal: true)
            }
            .sheet(isPresented: $showEdit) {
                AddFirearmView(editingFirearm: firearm)
            }
            .sheet(isPresented: $showAddSetup) {
                AddSetupView(firearm: firearm)
            }
    }

    private var content: some View {
        List {
            Section("Overview") {
                HStack {
                    Text("Firearm")
                    Spacer()
                    Text(firearm.displayName)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Class")
                    Spacer()
                    Text(firearm.firearmClass.rawValue)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Caliber")
                    Spacer()
                    Text(firearm.caliber)
                        .foregroundStyle(.secondary)
                }

                if let sn = firearm.serialNumber, !sn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack {
                        Text("Serial")
                        Spacer()
                        Text(sn)
                            .foregroundStyle(.secondary)
                    }
                }

                if let purchased = firearm.purchaseDate {
                    HStack {
                        Text("Purchased")
                        Spacer()
                        Text(purchased.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }

                if let lastUsed = firearm.lastUsedDate {
                    HStack {
                        Text("Last used")
                        Spacer()
                        Text(lastUsed.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Total rounds")
                    Spacer()
                    Text("\(firearm.totalRounds)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Analytics") {
                Button {
                    if entitlements.isPro {
                        Task { @MainActor in
                            analyticsPayload = sessions.map(SessionSnapshot.init)
                            showFirearmAnalytics = true
                        }
                    } else {
                        showAnalyticsPaywall = true
                    }
                } label: {
                    HStack {
                        Label("View Analytics", systemImage: "chart.bar.xaxis")
                        Spacer()
                        if !entitlements.isPro {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                if !entitlements.isPro {
                    Text("Upgrade to Pro to unlock analytics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Setups") {
                if firearm.setups.isEmpty {
                    Text("No setups yet.")
                        .foregroundStyle(.secondary)

                    Button {
                        showAddSetup = true
                    } label: {
                        Label("Add Setup", systemImage: "plus.circle.fill")
                    }
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
                                        Text(setup.name)
                                            .font(.headline)

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
                        }
                    }

                    Button {
                        showAddSetup = true
                    } label: {
                        Label("Add Setup", systemImage: "plus")
                    }
                }
            }

            Section("Sessions") {
                if sessions.isEmpty {
                    Text("No sessions logged yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { s in
                        NavigationLink {
                            SessionDetailView(session: s)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("\(s.rounds) rounds")
                                        .font(.headline)
                                    Spacer()
                                    Text(s.date, style: .date)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                if let ammo = s.ammo {
                                    Text(ammo.displayName)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                if let notes = s.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                HStack(spacing: 0) {
                                    indicatorCell(
                                        systemName: "photo.on.rectangle.angled",
                                        value: s.photos.isEmpty ? nil : "\(s.photos.count)"
                                    )

                                    indicatorCell(
                                        systemName: "exclamationmark.triangle",
                                        value: (s.malfunctions?.total ?? 0) > 0 ? "\(s.malfunctions!.total)" : nil
                                    )

                                    indicatorCell(
                                        systemName: "timer",
                                        value: (s.durationSeconds ?? 0) > 0
                                            ? "\(max(1, (s.durationSeconds ?? 0) / 60))m"
                                            : nil
                                    )
                                }
                                .frame(maxWidth: .infinity)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .neonCard(cornerRadius: 16, intensity: 0.35)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        showLog = true
                    } label: {
                        Label("Log", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func indicatorCell(systemName: String, value: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.footnote)

            Text(value ?? "—")
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(value == nil ? 0.3 : 1.0)
    }
}
