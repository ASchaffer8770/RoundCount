//
//  AddSetupView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import SwiftUI
import SwiftData

struct AddSetupView: View {
    let firearm: Firearm

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var makeActive: Bool = true
    @State private var notes: String = ""

    var body: some View {
            Form {
                Section("Setup") {
                    TextField("Name (e.g., Carry / USPSA)", text: $name)
                    Toggle("Set as active", isOn: $makeActive)
                }

                Section("Notes (optional)") {
                    TextField("Notes…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Add Setup")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Enforce single active setup
        if makeActive {
            for s in firearm.setups { s.isActive = false }
        }

        let setup = FirearmSetup(
            firearm: firearm,
            name: trimmed,
            isActive: makeActive,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        )

        modelContext.insert(setup)
        firearm.setups.append(setup)

        dismiss()
    }
}
