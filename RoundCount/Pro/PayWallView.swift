//
//  PayWallView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI
import SwiftData

struct PaywallView: View {
    @EnvironmentObject private var entitlements: Entitlements
    @Environment(\.dismiss) private var dismiss

    let sourceFeature: Feature?

    // Pricing (pre-StoreKit placeholders)
    private let monthlyPriceText = "$4.99 / month"
    private let yearlyPriceText = "$49.99 / year"
    private let yearlySavingsText = "Save ~17% vs monthly"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    header

                    if let feature = sourceFeature {
                        spotlight(feature)
                    } else {
                        Text("Upgrade to unlock Pro features.")
                            .foregroundStyle(.secondary)
                    }

                    pricingCards

                    featuresList

                    devPurchaseButtons

                    finePrint
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

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RoundCount Pro")
                .font(.title.bold())

            Text("Train smarter. Review faster. Track what matters.")
                .foregroundStyle(.secondary)
        }
    }

    private func spotlight(_ feature: Feature) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Includes **\(feature.title)**")
                .font(.headline)

            Text(feature.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .neonCard(cornerRadius: 16, intensity: 0.35)
    }

    private var pricingCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pricing")
                .font(.headline)

            VStack(spacing: 12) {
                priceCard(
                    title: "Monthly",
                    price: monthlyPriceText,
                    badge: nil
                )

                priceCard(
                    title: "Yearly",
                    price: yearlyPriceText,
                    badge: yearlySavingsText
                )
            }
        }
    }

    private func priceCard(title: String, price: String, badge: String?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(price)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let badge {
                Text(badge)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .neonCard(cornerRadius: 16, intensity: 0.35)
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you get")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(Feature.allCases) { f in
                    featureRow(f)
                }
            }
        }
    }

    private func featureRow(_ f: Feature) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(f.title)
                    .font(.headline)

                Text(f.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .neonCard(cornerRadius: 14, intensity: 0.30)
    }

    private var devPurchaseButtons: some View {
        VStack(spacing: 10) {

            if Entitlements.allowBetaProPurchase {
                Button {
                    entitlements.setTier(.pro)
                    dismiss()
                } label: {
                    Text("Unlock Pro (Beta)")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            } else {
                // When StoreKit is implemented, this becomes real purchase buttons.
                Button {
                    // no-op for now
                } label: {
                    Text("Coming soon")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }

            Button("Not now") { dismiss() }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }

    private var finePrint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Local-first, privacy-first.")
                .font(.footnote.weight(.semibold))

            Text("Your data stays on-device. No accounts. No ads. Cancel anytime.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }
}

#Preview("Paywall (Minimal)") {
    PaywallView(sourceFeature: nil)
        .environmentObject(Entitlements())
}

