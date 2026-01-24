//
//  FirearmMagazineEditorView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/20/26.
//

import SwiftUI
import SwiftData

struct FirearmMagazinesEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlements: Entitlements

    let firearm: Firearm

    @State private var newCapacity: Int = 17
    @State private var newLabel: String = ""

    // ✅ Pro gating UI
    @State private var showPaywall = false
    @State private var paywallFeature: Feature? = nil
    @State private var gateMessage: String? = nil
    @State private var showGateAlert = false

    private var magsSorted: [FirearmMagazine] {
        firearm.magazines.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            Section("Add Magazine") {
                Stepper(value: $newCapacity, in: 1...100) {
                    HStack {
                        Text("Capacity")
                        Spacer()
                        Text("\(newCapacity)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                TextField("Label (optional) — e.g. OEM, MBX, #2", text: $newLabel)

                Button {
                    addMagazine()
                } label: {
                    Label("Add Magazine", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Saved Magazines") {
                if magsSorted.isEmpty {
                    Text("No magazines yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(magsSorted) { mag in
                        HStack {
                            Text(mag.displayName)
                            Spacer()
                            Text(mag.firearm.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .opacity(0.0) // keeps row height consistent, but hides redundancy
                        }
                    }
                    .onDelete { idxSet in
                        // ✅ You said: Free cannot add magazines. Deleting is fine.
                        // If you want Free to be unable to *manage* magazines too, gate this as well.
                        for idx in idxSet {
                            let mag = magsSorted[idx]
                            firearm.magazines.removeAll(where: { $0.id == mag.id })
                            modelContext.delete(mag)
                        }
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle("Magazines")

        // ✅ Paywall + alert
        .sheet(isPresented: $showPaywall) {
            PayWallView(
                title: "RoundCount Pro",
                subtitle: "Upgrade to unlock Pro features."
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

    private func addMagazine() {
        guard entitlements.isPro else {
            // Recommended: add Feature.magazines for clean messaging.
            paywallFeature = .magazines
            gateMessage = "Magazines are a Pro feature. Upgrade to save capacities per firearm for faster round logging."
            showGateAlert = true
            return
        }

        let trimmedLabel = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let mag = FirearmMagazine(
            firearm: firearm,
            capacity: newCapacity,
            label: trimmedLabel.isEmpty ? nil : trimmedLabel
        )

        modelContext.insert(mag)
        firearm.magazines.append(mag)
        try? modelContext.save()

        newLabel = ""
    }
}
