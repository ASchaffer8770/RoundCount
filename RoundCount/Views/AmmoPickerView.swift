//
//  AmmoPickerView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI
import SwiftData

enum CaseMaterial: String, CaseIterable, Identifiable {
    case brass = "Brass"
    case steel = "Steel"
    case aluminum = "Aluminum"
    case nickel = "Nickel"
    case other = "Other"

    var id: String { rawValue }
}

struct AmmoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AmmoProduct.createdAt, order: .reverse) private var ammo: [AmmoProduct]

    @Binding var selectedAmmo: AmmoProduct?

    @State private var searchText: String = ""
    @State private var showAdd = false

    // ✅ NEW: edit sheet state
    @State private var editingAmmo: AmmoProduct? = nil

    private var filtered: [AmmoProduct] {
        if searchText.isEmpty { return ammo }
        return ammo.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add New Ammo", systemImage: "plus")
                    }
                }

                Section("Saved Ammo") {
                    if filtered.isEmpty {
                        Text("No ammo saved yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filtered) { a in
                            Button {
                                selectedAmmo = a
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(a.displayName)
                                    HStack {
                                        Text(a.brand)
                                        Spacer()
                                        if let qty = a.quantityPerBox {
                                            Text("\(qty)/box")
                                        }
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // ✅ NEW: Edit action
                                Button {
                                    editingAmmo = a
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    deleteAmmo(with: a.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select Ammo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddAmmoView(selectedAmmo: $selectedAmmo)
            }
            // ✅ NEW: edit sheet
            .sheet(item: $editingAmmo) { ammo in
                AddAmmoView(selectedAmmo: $selectedAmmo, editingAmmo: ammo)
            }
        }
    }

    private func deleteAmmo(with id: UUID) {
        if let item = ammo.first(where: { $0.id == id }) {
            modelContext.delete(item)
        }
    }
}

private struct AddAmmoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedAmmo: AmmoProduct?

    // ✅ NEW: if present, we are editing (not creating)
    let editingAmmo: AmmoProduct?

    @State private var brand: String
    @State private var productLine: String
    @State private var caliber: String
    @State private var grainText: String
    @State private var bulletType: BulletType
    @State private var roundsPerBoxText: String
    @State private var caseMaterial: CaseMaterial
    @State private var notes: String

    // ✅ NEW: custom init to prefill fields when editing
    init(selectedAmmo: Binding<AmmoProduct?>, editingAmmo: AmmoProduct? = nil) {
        self._selectedAmmo = selectedAmmo
        self.editingAmmo = editingAmmo

        _brand = State(initialValue: editingAmmo?.brand ?? "")
        _productLine = State(initialValue: editingAmmo?.productLine ?? "")
        _caliber = State(initialValue: editingAmmo?.caliber ?? "9mm")
        _grainText = State(initialValue: editingAmmo != nil ? "\(editingAmmo!.grain)" : "115")
        _bulletType = State(initialValue: BulletType(rawValue: editingAmmo?.bulletTypeRaw ?? BulletType.fmj.rawValue) ?? .fmj)
        _roundsPerBoxText = State(initialValue: editingAmmo?.quantityPerBox != nil ? "\(editingAmmo!.quantityPerBox!)" : "50")
        _caseMaterial = State(initialValue: CaseMaterial(rawValue: editingAmmo?.caseMaterial ?? CaseMaterial.brass.rawValue) ?? .brass)
        _notes = State(initialValue: editingAmmo?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Brand (e.g., CCI, Federal, Winchester)", text: $brand)
                        .textInputAutocapitalization(.words)

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Product name / line (optional)", text: $productLine)
                            .textInputAutocapitalization(.words)
                        Text("Example: Blazer Brass, White Box, American Eagle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Caliber (e.g., 9mm, .223, .45 ACP)", text: $caliber)
                            .textInputAutocapitalization(.never)
                        Text("Caliber is the cartridge type (ex: 9mm).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Bullet weight (gr) (e.g., 115)", text: $grainText)
                            .keyboardType(.numberPad)
                        Text("“gr” = grains. Common 9mm: 115 / 124 / 147")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Bullet Type", selection: $bulletType) {
                        ForEach(BulletType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Rounds per box (e.g., 50)", text: $roundsPerBoxText)
                            .keyboardType(.numberPad)
                        Text("How many rounds are in the box (20 / 50 / 100 / 200).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Case Material", selection: $caseMaterial) {
                        ForEach(CaseMaterial.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(editingAmmo == nil ? "Add Ammo" : "Edit Ammo")
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
    }

    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !caliber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(grainText) != nil &&
        Int(roundsPerBoxText) != nil
    }

    private func save() {
        guard let grain = Int(grainText) else { return }
        let roundsPerBox = Int(roundsPerBoxText)

        let cleanedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLine = productLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCaliber = caliber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = editingAmmo {
            // ✅ UPDATE existing record (no insert)
            existing.brand = cleanedBrand
            existing.productLine = cleanedLine.isEmpty ? nil : cleanedLine
            existing.caliber = cleanedCaliber
            existing.grain = grain
            existing.bulletTypeRaw = bulletType.rawValue
            existing.quantityPerBox = roundsPerBox
            existing.caseMaterial = caseMaterial.rawValue
            existing.notes = cleanedNotes.isEmpty ? nil : cleanedNotes

            selectedAmmo = existing
            dismiss()
            return
        }

        // ✅ CREATE new record
        let ammo = AmmoProduct(
            brand: cleanedBrand,
            productLine: cleanedLine.isEmpty ? nil : cleanedLine,
            caliber: cleanedCaliber,
            grain: grain,
            bulletType: bulletType,
            quantityPerBox: roundsPerBox,
            caseMaterial: caseMaterial.rawValue,
            notes: cleanedNotes.isEmpty ? nil : cleanedNotes
        )

        modelContext.insert(ammo)
        selectedAmmo = ammo
        dismiss()
    }
}
