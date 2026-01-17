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

    @State private var showAddGear = false
    @State private var isActiveToggle: Bool = false

    var body: some View {
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
        .navigationTitle("Setup")
        .onAppear { isActiveToggle = setup.isActive }
        .sheet(isPresented: $showAddGear) {
            AddGearView(setup: setup)
        }
    }

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
    }

    private func deleteGear(at offsets: IndexSet) {
        let sorted = setup.gear.sorted { $0.createdAt > $1.createdAt }
        for idx in offsets {
            let item = sorted[idx]
            modelContext.delete(item)
        }
    }

    private func batterySummary(_ b: BatteryInfo) -> String {
        var parts: [String] = []
        if let type = b.batteryType, !type.isEmpty { parts.append(type) }
        if let date = b.installedAt { parts.append("Installed \(date.formatted(date: .abbreviated, time: .omitted))") }
        return parts.isEmpty ? "Battery" : parts.joined(separator: " • ")
    }
}

