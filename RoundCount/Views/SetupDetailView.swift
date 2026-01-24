//
//  SetupDetailView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import SwiftUI
import SwiftData

struct SetupDetailView: View {
    let firearm: Firearm
    let setup: FirearmSetup

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlements: Entitlements

    @State private var showAddGear = false
    @State private var isActiveToggle: Bool = false

    // ✅ Pro gating UI
    @State private var showPaywall = false
    @State private var paywallFeature: Feature? = nil
    @State private var gateMessage: String? = nil
    @State private var showGateAlert = false

    var body: some View {
        Group {
            if entitlements.isPro {
                proContent
            } else {
                lockedContent
            }
        }
        .navigationTitle("Setup")
        .onAppear { isActiveToggle = setup.isActive }

        // ✅ Paywall + alert
        .sheet(isPresented: $showPaywall) {
            PayWallView(
                title: "RoundCount Pro",
                subtitle: gateMessage
            )
            .environmentObject(entitlements)
        }
        .alert("Upgrade to Pro", isPresented: $showGateAlert) {
            Button("Not now", role: .cancel) {}
            Button("See Pro") { showPaywall = true }
        } message: {
            Text(gateMessage ?? "This feature requires RoundCount Pro.")
        }
    }

    // MARK: - Locked (Free)

    private var lockedContent: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Setups & Gear are Pro")
                        .font(.headline)

                    Text("Upgrade to create setups (optic/light/etc.), add gear, and track batteries.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        paywallFeature = .firearmSetups
                        showPaywall = true
                    } label: {
                        Text("See Pro")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 6)
            }

            Section("Setup") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(setup.name).foregroundStyle(.secondary)
                }

                // ✅ Read-only indicator for Free
                HStack {
                    Text("Active")
                    Spacer()
                    Text(setup.isActive ? "Yes" : "No")
                        .foregroundStyle(.secondary)
                }

                if let notes = setup.notes, !notes.isEmpty {
                    Text(notes)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Gear") {
                if setup.gear.isEmpty {
                    Text("No gear yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(setup.gear.sorted { $0.createdAt > $1.createdAt }) { g in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(g.type.label)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                                Spacer()
                            }

                            Text(g.displayName)
                                .font(.headline)

                            if let b = g.battery, (b.batteryType != nil || b.installedAt != nil) {
                                Text(batterySummary(b))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let notes = g.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Button {
                    paywallFeature = .firearmSetups
                    gateMessage = "Upgrade to Pro to add gear items to a setup."
                    showGateAlert = true
                } label: {
                    Label("Add Gear", systemImage: "plus")
                }
                .disabled(true) // makes it visually obvious it’s locked
            }
        }
    }

    // MARK: - Pro content (full functionality)

    private var proContent: some View {
        List {
            Section("Setup") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(setup.name).foregroundStyle(.secondary)
                }

                Toggle("Active", isOn: $isActiveToggle)
                    .onChange(of: isActiveToggle) { _, newValue in
                        setActive(newValue)
                    }

                if let notes = setup.notes, !notes.isEmpty {
                    Text(notes)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Gear") {
                if setup.gear.isEmpty {
                    Text("No gear yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(setup.gear.sorted { $0.createdAt > $1.createdAt }) { g in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(g.type.label)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())

                                Spacer()
                            }

                            Text(g.displayName)
                                .font(.headline)

                            if let b = g.battery, (b.batteryType != nil || b.installedAt != nil) {
                                Text(batterySummary(b))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let notes = g.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteGear)
                }

                Button {
                    showAddGear = true
                } label: {
                    Label("Add Gear", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddGear) {
            AddGearView(setup: setup)
        }
    }

    // MARK: - Actions

    private func setActive(_ makeActive: Bool) {
        if makeActive {
            // Make this active, others inactive
            for s in firearm.setups { s.isActive = (s.id == setup.id) }
            isActiveToggle = true
        } else {
            // Allow turning off, leaving none active (fine for MVP)
            setup.isActive = false
            isActiveToggle = false
        }

        try? modelContext.save()
    }

    private func deleteGear(at offsets: IndexSet) {
        let sorted = setup.gear.sorted { $0.createdAt > $1.createdAt }
        for idx in offsets {
            let item = sorted[idx]
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func batterySummary(_ b: BatteryInfo) -> String {
        var parts: [String] = []
        if let type = b.batteryType, !type.isEmpty { parts.append(type) }
        if let date = b.installedAt { parts.append("Installed \(date.formatted(date: .abbreviated, time: .omitted))") }
        return parts.isEmpty ? "Battery" : parts.joined(separator: " • ")
    }
}
