//
//  AddAmmoView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/20/26.
//

import SwiftUI
import SwiftData

struct AddAmmoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let editingAmmo: AmmoProduct?

    @State private var brand: String = ""
    @State private var productLine: String = ""
    @State private var caliber: String = ""
    @State private var grainText: String = ""
    @State private var bulletType: BulletType = .fmj

    @State private var quantityPerBoxText: String = ""
    @State private var caseMaterial: String = ""
    @State private var notes: String = ""

    init(editingAmmo: AmmoProduct? = nil) {
        self.editingAmmo = editingAmmo

        _brand = State(initialValue: editingAmmo?.brand ?? "")
        _productLine = State(initialValue: editingAmmo?.productLine ?? "")
        _caliber = State(initialValue: editingAmmo?.caliber ?? "")
        _grainText = State(initialValue: editingAmmo.map { String($0.grain) } ?? "")
        _bulletType = State(initialValue: editingAmmo?.bulletType ?? .fmj)

        _quantityPerBoxText = State(initialValue: editingAmmo?.quantityPerBox.map(String.init) ?? "")
        _caseMaterial = State(initialValue: editingAmmo?.caseMaterial ?? "")
        _notes = State(initialValue: editingAmmo?.notes ?? "")
    }

    var body: some View {
            Form {
                Section("Core") {
                    TextField("Brand (e.g., CCI, Federal)", text: $brand)
                        .textInputAutocapitalization(.words)

                    TextField("Product line (optional)", text: $productLine)
                        .textInputAutocapitalization(.words)

                    TextField("Caliber (e.g., 9mm, .223)", text: $caliber)
                        .textInputAutocapitalization(.never)

                    TextField("Grain (e.g., 115)", text: $grainText)
                        .keyboardType(.numberPad)

                    Picker("Bullet type", selection: $bulletType) {
                        ForEach(BulletType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }

                Section("Optional") {
                    TextField("Qty per box (e.g., 50)", text: $quantityPerBoxText)
                        .keyboardType(.numberPad)

                    TextField("Case material (Brass/Steel/Aluminum)", text: $caseMaterial)
                        .textInputAutocapitalization(.words)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section {
                    Text("Name format is built automatically: Brand + Product Line • Caliber • Grain • Bullet Type.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(editingAmmo == nil ? "Add Ammo" : "Edit Ammo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
    }

    private var canSave: Bool {
        let b = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = caliber.trimmingCharacters(in: .whitespacesAndNewlines)
        let g = Int(grainText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return !b.isEmpty && !c.isEmpty && g > 0
    }

    private func save() {
        let b = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let line = productLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = caliber.trimmingCharacters(in: .whitespacesAndNewlines)

        let grain = Int(grainText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let qty = Int(quantityPerBoxText.trimmingCharacters(in: .whitespacesAndNewlines))
        let qtyOrNil: Int? = (qty ?? 0) > 0 ? qty : nil

        let mat = caseMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
        let matOrNil: String? = mat.isEmpty ? nil : mat

        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesOrNil: String? = n.isEmpty ? nil : n

        if let editingAmmo {
            editingAmmo.brand = b
            editingAmmo.productLine = line.isEmpty ? nil : line
            editingAmmo.caliber = c
            editingAmmo.grain = grain
            editingAmmo.bulletTypeRaw = bulletType.rawValue
            editingAmmo.quantityPerBox = qtyOrNil
            editingAmmo.caseMaterial = matOrNil
            editingAmmo.notes = notesOrNil
        } else {
            let a = AmmoProduct(
                brand: b,
                productLine: line.isEmpty ? nil : line,
                caliber: c,
                grain: grain,
                bulletType: bulletType,
                quantityPerBox: qtyOrNil,
                caseMaterial: matOrNil,
                notes: notesOrNil
            )
            modelContext.insert(a)
        }

        dismiss()
    }
}


#Preview {
    AddAmmoView()
}
