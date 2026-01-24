//
//  AddSetupView.swift
//  RoundCount
//

import SwiftUI
import SwiftData

struct AddSetupView: View {
    let firearm: Firearm

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var entitlements: Entitlements

    @State private var name: String = ""
    @State private var makeActive: Bool = true
    @State private var notes: String = ""

    // ✅ Pro gating UI
    @State private var showPaywall = false
    @State private var paywallFeature: Feature? = nil
    @State private var gateMessage: String? = nil
    @State private var showGateAlert = false

    var body: some View {
        VStack(spacing: 0) {

            // ✅ Sheet-safe header (Cancel / Save)
            SheetHeaderBar(
                title: "Add Setup",
                onCancel: { dismiss() },
                onSave: { save() },
                saveEnabled: canSave
            )

            Form {
                Section("Setup") {
                    TextField("Name (e.g., Carry / USPSA)", text: $name)
                        .textInputAutocapitalization(.words)

                    Toggle("Set as active", isOn: $makeActive)
                }

                Section("Notes (optional)") {
                    TextField("Notes…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Brand.pageBackground(scheme))

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

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard entitlements.isPro else {
            paywallFeature = .firearmSetups
            gateMessage = "Setups & gear are a Pro feature. Upgrade to create setups (optic/light/etc.) for each firearm."
            showGateAlert = true
            return
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Enforce single active setup
        if makeActive {
            for s in firearm.setups { s.isActive = false }
        }

        let nTrimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let setup = FirearmSetup(
            firearm: firearm,
            name: trimmed,
            isActive: makeActive,
            notes: nTrimmed.isEmpty ? nil : nTrimmed
        )

        modelContext.insert(setup)
        firearm.setups.append(setup)

        try? modelContext.save()
        dismiss()
    }
}
