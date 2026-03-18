import SwiftUI
import SwiftData

struct StockAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme

    let ammo: AmmoProduct

    enum Mode: String, CaseIterable, Identifiable {
        case add = "Add"
        case remove = "Remove"
        var id: String { rawValue }
    }

    enum EntryUnit: String, CaseIterable, Identifiable {
        case rounds = "Rounds"
        case boxes = "Boxes"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .add
    @State private var entryUnit: EntryUnit = .rounds
    @State private var quantityText: String = ""

    private var parsedQty: Int? {
        let n = Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let n, n > 0 else { return nil }
        return n
    }

    private var roundsDelta: Int? {
        guard let qty = parsedQty else { return nil }
        if entryUnit == .boxes {
            guard let qpb = ammo.quantityPerBox, qpb > 0 else { return nil }
            return qty * qpb
        }
        return qty
    }

    private var previewTotal: Int? {
        guard let delta = roundsDelta else { return nil }
        let current = ammo.roundsOnHand ?? 0
        switch mode {
        case .add:    return current + delta
        case .remove: return max(0, current - delta)
        }
    }

    private var canSave: Bool { roundsDelta != nil }

    private var isFirstTimeTracking: Bool { !ammo.isTrackingInventory }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderBar(
                title: isFirstTimeTracking ? "Track Inventory" : "Adjust Stock",
                onCancel: { dismiss() },
                onSave: { save() },
                saveEnabled: canSave
            )

            Form {
                if isFirstTimeTracking {
                    Section {
                        Text("Enter how many rounds you currently have on hand. RoundCount will track this going forward and subtract rounds automatically when you log sessions.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }

                Section {
                    if ammo.quantityPerBox != nil {
                        Picker("Unit", selection: $entryUnit) {
                            ForEach(EntryUnit.allCases) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        TextField(entryUnit == .rounds ? "Rounds" : "Boxes", text: $quantityText)
                            .keyboardType(.numberPad)

                        if entryUnit == .boxes, let qpb = ammo.quantityPerBox, let qty = parsedQty {
                            Spacer()
                            Text("= \(qty * qpb) rounds")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Quantity")
                }

                Section {
                    HStack {
                        Text("Current")
                        Spacer()
                        Text(ammo.inventoryDisplayText)
                            .foregroundStyle(.secondary)
                    }

                    if let total = previewTotal {
                        HStack {
                            Text("After adjustment")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(total) round\(total == 1 ? "" : "s")")
                                .fontWeight(.semibold)
                                .foregroundStyle(total == 0 ? .orange : Brand.accent)
                        }
                    }
                } header: {
                    Text("Preview")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Brand.pageBackground(scheme))
    }

    private func save() {
        guard let delta = roundsDelta else { return }
        let current = ammo.roundsOnHand ?? 0
        switch mode {
        case .add:    ammo.roundsOnHand = current + delta
        case .remove: ammo.roundsOnHand = max(0, current - delta)
        }
        try? modelContext.save()
        dismiss()
    }
}
