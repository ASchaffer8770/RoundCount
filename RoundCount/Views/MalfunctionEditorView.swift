//
//  MalfunctionEditorView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import SwiftUI

struct MalfunctionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var draft: MalfunctionDraft

    var body: some View {
            Form {
                Section("Malfunctions") {
                    StepperRow(title: "Failure to Feed", value: $draft.failureToFeed)
                    StepperRow(title: "Failure to Eject", value: $draft.failureToEject)
                    StepperRow(title: "Stovepipe", value: $draft.stovepipe)
                    StepperRow(title: "Double Feed", value: $draft.doubleFeed)
                    StepperRow(title: "Light Strike", value: $draft.lightStrike)
                    StepperRow(title: "Other", value: $draft.other)
                }

                Section {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text("\(draft.total)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Malfunctions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
    }
}

private struct StepperRow: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        Stepper {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
                    .foregroundStyle(.secondary)
            }
        } onIncrement: {
            value += 1
        } onDecrement: {
            value = max(0, value - 1)
        }
    }
}

/// Lightweight UI state we can later convert into a `MalfunctionSummary` model at save time.
struct MalfunctionDraft {
    var failureToFeed: Int = 0
    var failureToEject: Int = 0
    var stovepipe: Int = 0
    var doubleFeed: Int = 0
    var lightStrike: Int = 0
    var other: Int = 0

    var total: Int {
        failureToFeed + failureToEject + stovepipe + doubleFeed + lightStrike + other
    }

    var isAllZero: Bool { total == 0 }
}

