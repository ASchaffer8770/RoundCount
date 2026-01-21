import SwiftUI
import SwiftData

struct AmmoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var ammo: AmmoProduct

    var body: some View {
        NavigationStack {
            Form {
                Section("Ammo") {
                    TextField("Brand", text: $ammo.brand)

                    TextField("Product Line (optional)", text: Binding(
                        get: { ammo.productLine ?? "" },
                        set: { ammo.productLine = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                    ))

                    TextField("Caliber", text: $ammo.caliber)

                    Stepper(value: $ammo.grain, in: 1...200) {
                        Text("Grain: \(ammo.grain)")
                    }

                    Picker("Bullet Type", selection: Binding(
                        get: { ammo.bulletType },
                        set: { ammo.bulletTypeRaw = $0.rawValue }
                    )) {
                        ForEach(BulletType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }

                Section("Optional") {
                    TextField("Quantity per box (optional)", value: Binding(
                        get: { ammo.quantityPerBox ?? 0 },
                        set: { ammo.quantityPerBox = $0 <= 0 ? nil : $0 }
                    ), format: .number)
                    .keyboardType(.numberPad)

                    TextField("Case material (optional)", text: Binding(
                        get: { ammo.caseMaterial ?? "" },
                        set: { ammo.caseMaterial = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                    ))
                }

                Section("Notes") {
                    TextEditor(text: Binding(
                        get: { ammo.notes ?? "" },
                        set: { ammo.notes = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 120)
                }
            }
            .navigationTitle("Edit Ammo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        try? modelContext.save()
        dismiss()
    }
}
