//
//  AddGearView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import SwiftUI
import SwiftData

struct AddGearView: View {
    let setup: FirearmSetup

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var type: GearType = .optic
    @State private var brand: String = ""
    @State private var model: String = ""
    @State private var notes: String = ""

    @State private var trackBattery: Bool = false
    @State private var batteryType: String = ""
    @State private var installedAt: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Gear") {
                    Picker("Type", selection: $type) {
                        ForEach(GearType.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }

                    TextField("Brand", text: $brand)
                    TextField("Model", text: $model)
                }

                Section("Battery (optional)") {
                    Toggle("Track battery", isOn: $trackBattery)

                    if trackBattery {
                        TextField("Battery type (e.g., CR1632)", text: $batteryType)
                        DatePicker("Installed", selection: $installedAt, displayedComponents: .date)

                        Button("Set Installed = Today") {
                            installedAt = .now
                        }
                    }
                }

                Section("Notes (optional)") {
                    TextField("Notes…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Add Gear")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let b = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !b.isEmpty, !m.isEmpty else { return }

        let battery: BatteryInfo? = trackBattery ? BatteryInfo(
            batteryType: batteryType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : batteryType,
            installedAt: installedAt,
            notes: nil,
            roundsSinceChange: nil,
            secondsSinceChange: nil
        ) : nil

        let item = GearItem(
            setup: setup,
            type: type,
            brand: b,
            model: m,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            battery: battery
        )

        modelContext.insert(item)
        setup.gear.append(item)

        dismiss()
    }
}

