//
//  AddGearView.swift
//  RoundCount
//

import SwiftUI
import SwiftData

struct AddGearView: View {
    let setup: FirearmSetup

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var entitlements: Entitlements

    @State private var type: GearType = .optic
    @State private var brand: String = ""
    @State private var model: String = ""
    @State private var notes: String = ""

    @State private var trackBattery: Bool = false
    @State private var batteryType: String = ""
    @State private var installedAt: Date = .now

    // ✅ Pro gating UI
    @State private var showPaywall = false
    @State private var paywallFeature: Feature? = nil
    @State private var gateMessage: String? = nil
    @State private var showGateAlert = false

    var body: some View {
        VStack(spacing: 0) {

            // ✅ Sheet-safe header (Cancel / Save)
            SheetHeaderBar(
                title: "Add Gear",
                onCancel: { dismiss() },
                onSave: { save() },
                saveEnabled: canSave
            )

            Form {
                Section("Gear") {
                    Picker("Type", selection: $type) {
                        ForEach(GearType.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }

                    TextField("Brand", text: $brand)
                        .textInputAutocapitalization(.words)

                    TextField("Model", text: $model)
                        .textInputAutocapitalization(.words)
                }

                Section("Battery (optional)") {
                    Toggle("Track battery", isOn: $trackBattery)

                    if trackBattery {
                        TextField("Battery type (e.g., CR1632)", text: $batteryType)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)

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
            .scrollContentBackground(.hidden)
        }
        .background(Brand.pageBackground(scheme))

        // ✅ Paywall + alert (unchanged)
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
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard entitlements.isPro else {
            paywallFeature = .firearmSetups
            gateMessage = "Setups & gear are a Pro feature. Upgrade to add gear (optic/light/etc.) and track batteries."
            showGateAlert = true
            return
        }

        let b = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !b.isEmpty, !m.isEmpty else { return }

        let bt = batteryType.trimmingCharacters(in: .whitespacesAndNewlines)
        let battery: BatteryInfo? = trackBattery ? BatteryInfo(
            batteryType: bt.isEmpty ? nil : bt,
            installedAt: installedAt,
            notes: nil,
            roundsSinceChange: nil,
            secondsSinceChange: nil
        ) : nil

        let nTrimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = GearItem(
            setup: setup,
            type: type,
            brand: b,
            model: m,
            notes: nTrimmed.isEmpty ? nil : nTrimmed,
            battery: battery
        )

        modelContext.insert(item)
        setup.gear.append(item)

        try? modelContext.save()
        dismiss()
    }
}
