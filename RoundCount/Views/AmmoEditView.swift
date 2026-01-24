//
//  AmmoEditView.swift
//  RoundCount
//

import SwiftUI
import SwiftData

struct AmmoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme

    @Bindable var ammo: AmmoProduct

    var body: some View {
        VStack(spacing: 0) {

            // ✅ Sheet header (Cancel / Save)
            SheetHeaderBar(
                title: "Edit Ammo",
                onCancel: { dismiss() },
                onSave: { save() },
                saveEnabled: canSave
            )

            Form {
                Section("Ammo") {
                    TextField("Brand", text: $ammo.brand)

                    TextField(
                        "Product Line (optional)",
                        text: Binding(
                            get: { ammo.productLine ?? "" },
                            set: {
                                ammo.productLine = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? nil
                                    : $0
                            }
                        )
                    )

                    TextField("Caliber", text: $ammo.caliber)

                    Stepper(value: $ammo.grain, in: 1...200) {
                        Text("Grain: \(ammo.grain)")
                    }

                    Picker(
                        "Bullet Type",
                        selection: Binding(
                            get: { ammo.bulletType },
                            set: { ammo.bulletTypeRaw = $0.rawValue }
                        )
                    ) {
                        ForEach(BulletType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }

                Section("Optional") {
                    TextField(
                        "Quantity per box (optional)",
                        value: Binding(
                            get: { ammo.quantityPerBox ?? 0 },
                            set: { ammo.quantityPerBox = $0 <= 0 ? nil : $0 }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)

                    TextField(
                        "Case material (optional)",
                        text: Binding(
                            get: { ammo.caseMaterial ?? "" },
                            set: {
                                ammo.caseMaterial = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? nil
                                    : $0
                            }
                        )
                    )
                }

                Section("Notes") {
                    TextEditor(
                        text: Binding(
                            get: { ammo.notes ?? "" },
                            set: {
                                ammo.notes = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? nil
                                    : $0
                            }
                        )
                    )
                    .frame(minHeight: 120)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Brand.pageBackground(scheme))
    }

    private var canSave: Bool {
        !ammo.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ammo.caliber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        ammo.grain > 0
    }

    private func save() {
        try? modelContext.save()
        dismiss()
    }
}
