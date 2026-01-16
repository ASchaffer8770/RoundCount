//
//  AddFirearmView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI
import SwiftData

struct AddFirearmView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // If present, we are editing an existing firearm
    let editingFirearm: Firearm?

    // Form fields
    @State private var brand: String
    @State private var model: String
    @State private var caliber: String
    @State private var firearmClass: FirearmClass

    @State private var serialNumber: String

    @State private var hasPurchaseDate: Bool
    @State private var purchaseDate: Date

    @State private var hasLastUsedDate: Bool
    @State private var lastUsedDate: Date

    init(editingFirearm: Firearm? = nil) {
        self.editingFirearm = editingFirearm

        _brand = State(initialValue: editingFirearm?.brand ?? "")
        _model = State(initialValue: editingFirearm?.model ?? "")
        _caliber = State(initialValue: editingFirearm?.caliber ?? "9mm")
        _firearmClass = State(initialValue: editingFirearm?.firearmClass ?? .other)

        _serialNumber = State(initialValue: editingFirearm?.serialNumber ?? "")

        let p = editingFirearm?.purchaseDate
        _hasPurchaseDate = State(initialValue: p != nil)
        _purchaseDate = State(initialValue: p ?? Date())

        let l = editingFirearm?.lastUsedDate
        _hasLastUsedDate = State(initialValue: l != nil)
        _lastUsedDate = State(initialValue: l ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Brand (e.g., Springfield, Glock)", text: $brand)
                        .textInputAutocapitalization(.words)

                    TextField("Model (e.g., Prodigy 5\")", text: $model)
                        .textInputAutocapitalization(.words)

                    TextField("Caliber (e.g., 9mm, .45 ACP)", text: $caliber)
                        .textInputAutocapitalization(.never)

                    Picker("Class", selection: $firearmClass) {
                        ForEach(FirearmClass.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Serial Number (optional)", text: $serialNumber)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)

                        Text("Serial numbers stay on this device. RoundCount does not collect or share this data.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Dates") {
                    Toggle("Purchase date", isOn: $hasPurchaseDate)
                    if hasPurchaseDate {
                        DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date)
                    }

                    Toggle("Last used date", isOn: $hasLastUsedDate)
                    if hasLastUsedDate {
                        DatePicker("Last used", selection: $lastUsedDate, displayedComponents: [.date, .hourAndMinute])
                    } else {
                        Text("Tip: “Last used” updates automatically when you log a session.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(editingFirearm == nil ? "Add Firearm" : "Edit Firearm")
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
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !caliber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let b = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = caliber.trimmingCharacters(in: .whitespacesAndNewlines)

        let snTrimmed = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let sn: String? = snTrimmed.isEmpty ? nil : snTrimmed

        let pDate: Date? = hasPurchaseDate ? purchaseDate : nil
        let lDate: Date? = hasLastUsedDate ? lastUsedDate : nil

        if let f = editingFirearm {
            // Update existing firearm
            f.brand = b
            f.model = m
            f.caliber = c
            f.firearmClassRaw = firearmClass.rawValue
            f.serialNumber = sn
            f.purchaseDate = pDate
            f.lastUsedDate = lDate
            dismiss()
            return
        }

        // Create new firearm
        let firearm = Firearm(
            brand: b,
            model: m,
            caliber: c,
            firearmClass: firearmClass,
            serialNumber: sn,
            purchaseDate: pDate,
            lastUsedDate: lDate
        )

        modelContext.insert(firearm)
        dismiss()
    }
}
