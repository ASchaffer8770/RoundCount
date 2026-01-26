//
//  PayWallView.swift
//  RoundCount
//
//  StoreKit 2 Paywall (no NavigationStack)
//  - Uses StoreKitManager for products/purchase/restore
//  - Calls Entitlements.refreshFromStoreKit() after purchase/restore
//
//  App Review compliance (3.1.2):
//  - Includes functional links to Privacy Policy + Terms of Use (Apple Standard EULA)
//  - Includes required auto-renew disclosure text
//  - Shows subscription name/price/length (via ProductRow + CTA period hint)
//  - Includes Restore Purchases
//

import SwiftUI
import StoreKit

struct PayWallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlements: Entitlements
    @EnvironmentObject private var store: StoreKitManager

    let title: String
    let subtitle: String?

    // App Review required links
    private let privacyURL = URL(string: "https://aschaffer8770.github.io/roundcount-privacy/")!
    private let termsURL   = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    @State private var selectedID: String? = nil

    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    /// Purchases must be functional in App Store builds.
    /// Keep beta gating only for DEBUG builds.
    private var purchasesEnabled: Bool {
        #if DEBUG
        return Entitlements.allowBetaProPurchase
        #else
        return true
        #endif
    }

    var body: some View {
        VStack(spacing: 14) {
            header

            VStack(spacing: 12) {
                featureList

                #if DEBUG
                if !purchasesEnabled {
                    purchasesDisabledBanner
                }
                #endif

                Divider().opacity(0.6)

                planPicker
                ctaButtons
            }
            .accentCard()

            legalRow
        }
        .padding()
        .background(Color(.systemBackground))
        .task { await boot() }
        .onChange(of: store.purchaseState) { _, newValue in
            handlePurchaseState(newValue)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Boot

    private func boot() async {
        isLoading = true

        // Only load if we don't already have them (app loads on launch)
        if store.products.isEmpty {
            await store.loadProducts()
        }

        if selectedID == nil { selectedID = defaultSelectionID }
        isLoading = false
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(10)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Upgrade to Pro to unlock the full experience.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 2)
        }
        .surfaceCard()
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabelRow(icon: "stopwatch", title: "Live Sessions v2", detail: "Runs, timing, and better session summaries.")
            LabelRow(icon: "camera", title: "Session Photos", detail: "Targets + malfunctions, tied to runs.")
            LabelRow(icon: "chart.line.uptrend.xyaxis", title: "Pro Analytics", detail: "Reliable totals and progress over time.")
            LabelRow(icon: "wrench.and.screwdriver", title: "Maintenance (coming)", detail: "Track wear items and round-based triggers.")
        }
        .padding(12)
        .surfaceCard()
    }

    // DEBUG-only: avoid any suggestion to reviewers that purchasing is disabled
    private var purchasesDisabledBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Purchases are disabled in this build")
                    .font(.system(size: 14, weight: .semibold))
                Text("Flip Entitlements.allowBetaProPurchase to true to test buying/restoring.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .surfaceCard()
    }

    // MARK: - Plans

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose a plan")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.9)
                }
            }

            if store.products.isEmpty && !isLoading {
                Text("No products found. Double-check App Store Connect product IDs and availability.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .surfaceCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(store.products.sorted(by: productSort), id: \.id) { p in
                        ProductRow(
                            product: p,
                            isSelected: (selectedID ?? defaultSelectionID) == p.id,
                            badgeText: badgeText(for: p),
                            subtitle: productSubtitle(for: p)
                        ) {
                            selectedID = p.id
                        }
                    }
                }
            }
        }
        .padding(12)
        .surfaceCard()
    }

    private var ctaButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchaseSelected() }
            } label: {
                HStack {
                    Spacer()
                    if store.purchaseState == .purchasing {
                        ProgressView().padding(.trailing, 6)
                    }
                    Text(buttonTitle)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .disabled(
                entitlements.isPro ||
                !purchasesEnabled ||
                selectedProduct == nil ||
                isLoading ||
                store.purchaseState == .purchasing
            )
            .buttonStyle(.borderedProminent)

            HStack(spacing: 10) {
                Button {
                    Task { await restore() }
                } label: {
                    HStack {
                        if store.purchaseState == .purchasing { ProgressView().scaleEffect(0.9) }
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .disabled(!purchasesEnabled || store.purchaseState == .purchasing)
                .buttonStyle(.bordered)

                Button { dismiss() } label: {
                    Text("Not now")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .surfaceCard()
    }

    // MARK: - Legal / Required Info

    private var legalRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Link("Privacy Policy", destination: privacyURL)
                Link("Terms of Use", destination: termsURL)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)

            Text(legalDisclosureText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 2)
    }

    private var legalDisclosureText: String {
        // Apple-required style disclosure (concise and safe)
        "Payment will be charged to your Apple ID at confirmation of purchase. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Manage or cancel in App Store account settings."
    }

    // MARK: - Derived

    private var defaultSelectionID: String? {
        // Prefer yearly, then monthly
        let ids = Set(store.products.map(\.id))
        if ids.contains(StoreKitManager.proYearlyID) { return StoreKitManager.proYearlyID }
        if ids.contains(StoreKitManager.proMonthlyID) { return StoreKitManager.proMonthlyID }
        return store.products.first?.id
    }

    private var selectedProduct: Product? {
        guard !store.products.isEmpty else { return nil }
        let id = selectedID ?? defaultSelectionID
        return store.products.first(where: { $0.id == id })
    }

    private var buttonTitle: String {
        if entitlements.isPro { return "You’re Pro ✅" }
        guard let p = selectedProduct else { return purchasesEnabled ? "Continue" : "Purchases Disabled" }

        let period = (p.id == StoreKitManager.proYearlyID) ? " / year" :
                     (p.id == StoreKitManager.proMonthlyID) ? " / month" : ""

        return purchasesEnabled ? "Continue • \(p.displayPrice)\(period)" : "Purchases Disabled"
    }

    // MARK: - Actions

    private func purchaseSelected() async {
        guard !entitlements.isPro else {
            dismiss()
            return
        }

        guard purchasesEnabled else {
            #if DEBUG
            presentAlert("Purchases disabled", "Enable Entitlements.allowBetaProPurchase to test purchases.")
            #else
            presentAlert("Purchases unavailable", "Purchases are currently unavailable. Please try again later.")
            #endif
            return
        }

        guard let product = selectedProduct else { return }

        let tx = await store.purchase(product)
        if tx != nil {
            await entitlements.refreshFromStoreKit()
            dismiss()
        }
        // If nil: state handler will show alert if needed
    }

    private func restore() async {
        guard purchasesEnabled else {
            #if DEBUG
            presentAlert("Purchases disabled", "Enable Entitlements.allowBetaProPurchase to test restores.")
            #else
            presentAlert("Restore unavailable", "Restoring purchases is currently unavailable. Please try again later.")
            #endif
            return
        }

        await store.restorePurchases()
        await entitlements.refreshFromStoreKit()

        if entitlements.isPro {
            dismiss()
        } else {
            presentAlert("Nothing to restore", "No active Pro subscription was found for this Apple ID.")
        }
    }

    private func handlePurchaseState(_ state: StoreKitManager.PurchaseState) {
        switch state {
        case .idle, .purchasing, .purchased:
            return
        case .cancelled:
            // quiet
            return
        case .failed(let msg):
            presentAlert("Purchase failed", msg)
        }
    }

    // MARK: - Helpers

    private func presentAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    private func productSort(_ a: Product, _ b: Product) -> Bool {
        // Yearly first, then monthly
        if a.id == StoreKitManager.proYearlyID { return true }
        if b.id == StoreKitManager.proYearlyID { return false }
        if a.id == StoreKitManager.proMonthlyID { return true }
        if b.id == StoreKitManager.proMonthlyID { return false }
        return a.displayPrice < b.displayPrice
    }

    private func badgeText(for product: Product) -> String? {
        if product.id == StoreKitManager.proYearlyID { return "Best value" }
        return nil
    }

    private func productSubtitle(for product: Product) -> String {
        if product.id == StoreKitManager.proMonthlyID { return "1 month • Auto-renews • Cancel anytime" }
        if product.id == StoreKitManager.proYearlyID { return "1 year • Auto-renews • Cancel anytime" }
        return "Auto-renewing subscription"
    }
}

// MARK: - UI Bits

private struct LabelRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

private struct ProductRow: View {
    let product: Product
    let isSelected: Bool
    let badgeText: String?
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(size: 14, weight: .semibold))
                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.primary.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
