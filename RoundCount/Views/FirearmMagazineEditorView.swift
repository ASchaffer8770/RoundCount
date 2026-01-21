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
    let firearm: Firearm

    @State private var newCapacity: Int = 17
    @State private var newLabel: String = ""

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
                    let mag = FirearmMagazine(
                        firearm: firearm,
                        capacity: newCapacity,
                        label: newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newLabel
                    )
                    modelContext.insert(mag)
                    firearm.magazines.append(mag)
                    try? modelContext.save()

                    newLabel = ""
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
    }
}

