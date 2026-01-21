//
//  QuickActionTile.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

//
//  QuickActionTile.swift
//  RoundCount
//

import SwiftUI

struct QuickActionTile: View {
    let title: String
    let systemImage: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 64) // makes it feel “tile-like”
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.l, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.l, style: .continuous))
    }
}

