//
//  SheetHeaderBar.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/23/26.
//

import SwiftUI

struct SheetHeaderBar: View {
    let title: String
    let onCancel: () -> Void
    let onSave: () -> Void
    let saveEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)

            Spacer()

            Text(title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Button("Save", action: onSave)
                .fontWeight(.semibold)
                .disabled(!saveEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(.quaternary),
            alignment: .bottom
        )
    }
}

