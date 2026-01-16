//
//  PayWallView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var entitlements: Entitlements
    @Environment(\.dismiss) private var dismiss

    let sourceFeature: Feature?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("RoundCount Pro")
                        .font(.title.bold())

                    if let feature = sourceFeature {
                        Text("Unlock **\(feature.title)** and more.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Upgrade to unlock Pro features.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ForEach(Feature.allCases) { f in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.title).font(.headline)
                                Text(f.description)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    // TEMP purchase button (until StoreKit)
                    Button {
                        entitlements.setTier(.pro)
                        dismiss()
                    } label: {
                        Text("Enable Pro (Dev)")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Not now") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Upgrade")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
