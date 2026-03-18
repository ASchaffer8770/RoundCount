//
//  AddAmmoView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/20/26.
//

import SwiftUI
import SwiftData
import VisionKit

struct AddAmmoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var entitlements: Entitlements

    let editingAmmo: AmmoProduct?

    @State private var showPaywall = false

    @State private var brand: String = ""
    @State private var productLine: String = ""
    @State private var caliber: String = ""
    @State private var grainText: String = ""
    @State private var bulletType: BulletType = .fmj

    @State private var quantityPerBoxText: String = ""
    @State private var caseMaterial: String = ""
    @State private var notes: String = ""

    // Barcode
    @State private var scannedUPC: String = ""
    @State private var showScanner = false
    @State private var lookupStatus: LookupStatus = .idle

    private enum LookupStatus {
        case idle
        case loading
        case cached           // instant hit from local cache
        case success          // live network hit
        case partialSuccess   // found product but couldn't parse ammo details
        case failure(String)
    }

    init(editingAmmo: AmmoProduct? = nil) {
        self.editingAmmo = editingAmmo

        _brand = State(initialValue: editingAmmo?.brand ?? "")
        _productLine = State(initialValue: editingAmmo?.productLine ?? "")
        _caliber = State(initialValue: editingAmmo?.caliber ?? "")
        _grainText = State(initialValue: editingAmmo.map { String($0.grain) } ?? "")
        _bulletType = State(initialValue: editingAmmo?.bulletType ?? .fmj)

        _quantityPerBoxText = State(initialValue: editingAmmo?.quantityPerBox.map(String.init) ?? "")
        _caseMaterial = State(initialValue: editingAmmo?.caseMaterial ?? "")
        _notes = State(initialValue: editingAmmo?.notes ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {

            SheetHeaderBar(
                title: editingAmmo == nil ? "Add Ammo" : "Edit Ammo",
                onCancel: { dismiss() },
                onSave: { save() },
                saveEnabled: canSave
            )

            Form {
                // Barcode section — add mode only
                if editingAmmo == nil {
                    Section {
                        scanRow
                        if !scannedUPC.isEmpty {
                            upcRow
                        }
                    } footer: {
                        lookupFooter
                    }
                }

                Section("Core") {
                    TextField("Brand (e.g., CCI, Federal)", text: $brand)
                        .textInputAutocapitalization(.words)

                    TextField("Product line (optional)", text: $productLine)
                        .textInputAutocapitalization(.words)

                    TextField("Caliber (e.g., 9mm, .223)", text: $caliber)
                        .textInputAutocapitalization(.never)

                    TextField("Grain (e.g., 115)", text: $grainText)
                        .keyboardType(.numberPad)

                    Picker("Bullet type", selection: $bulletType) {
                        ForEach(BulletType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }

                Section("Optional") {
                    TextField("Qty per box (e.g., 50)", text: $quantityPerBoxText)
                        .keyboardType(.numberPad)

                    TextField("Case material (Brass/Steel/Aluminum)", text: $caseMaterial)
                        .textInputAutocapitalization(.words)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section {
                    Text("Name format is built automatically: Brand + Product Line • Caliber • Grain • Bullet Type.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Brand.pageBackground(scheme))
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet { upc in
                scannedUPC = upc
                performLookup(upc: upc)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PayWallView(title: "RoundCount Pro", subtitle: nil)
                .environmentObject(entitlements)
        }
    }

    // MARK: - Scan Section Subviews

    @ViewBuilder
    private var scanRow: some View {
        if case .loading = lookupStatus {
            HStack(spacing: 10) {
                ProgressView()
                Text("Looking up barcode…")
                    .foregroundStyle(.secondary)
            }
        } else if DataScannerViewController.isSupported {
            Button {
                if entitlements.isPro {
                    showScanner = true
                } else {
                    showPaywall = true
                }
            } label: {
                Label(
                    scannedUPC.isEmpty ? "Scan Barcode" : "Scan Again",
                    systemImage: "barcode.viewfinder"
                )
                .foregroundStyle(Brand.accent)
            }
        }
    }

    @ViewBuilder
    private var upcRow: some View {
        HStack {
            Image(systemName: upcRowIcon)
                .foregroundStyle(upcRowIconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("UPC: \(scannedUPC)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Clear") {
                scannedUPC = ""
                lookupStatus = .idle
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var upcRowIcon: String {
        switch lookupStatus {
        case .success, .cached: return "checkmark.circle.fill"
        case .failure:          return "exclamationmark.circle"
        default:                return "barcode"
        }
    }

    private var upcRowIconColor: Color {
        switch lookupStatus {
        case .success, .cached: return .green
        case .failure:          return .orange
        default:                return .secondary
        }
    }

    @ViewBuilder
    private var lookupFooter: some View {
        switch lookupStatus {
        case .idle:
            Text("Scan a UPC barcode to auto-fill the fields below.")
        case .loading:
            Text("Searching product database…")
        case .cached:
            Text("Loaded from cache — review and save when ready.")
                .foregroundStyle(.green)
        case .success:
            Text("Fields auto-filled — review and save when ready.")
                .foregroundStyle(.green)
        case .partialSuccess:
            Text("Product found but ammo details couldn't be parsed. Fill in manually.")
                .foregroundStyle(.secondary)
        case .failure(let msg):
            Text(msg)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Lookup

    private func performLookup(upc: String) {
        // Cache check — instant, no loading state needed
        let descriptor = FetchDescriptor<UPCLookupCache>(
            predicate: #Predicate { $0.upc == upc }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            applyResult(cached.asBarcodeResult)
            lookupStatus = .cached
            return
        }

        // Cache miss — hit the network
        lookupStatus = .loading
        Task {
            do {
                let result = try await BarcodeService.shared.lookup(upc: upc)
                if result.hasAnyAmmoData {
                    modelContext.insert(UPCLookupCache(upc: upc, result: result))
                    applyResult(result)
                    lookupStatus = .success
                } else {
                    lookupStatus = .partialSuccess
                }
            } catch let e as BarcodeServiceError {
                lookupStatus = .failure(e.errorDescription ?? "Lookup failed. Fill in manually.")
            } catch {
                lookupStatus = .failure("Lookup failed. Fill in manually.")
            }
        }
    }

    private func applyResult(_ result: BarcodeResult) {
        if let v = result.brand,        !v.isEmpty { brand = v }
        if let v = result.productLine,  !v.isEmpty { productLine = v }
        if let v = result.caliber,      !v.isEmpty { caliber = v }
        if let v = result.grain,        v > 0      { grainText = String(v) }
        if let v = result.bulletType               { bulletType = v }
        if let v = result.quantityPerBox, v > 0   { quantityPerBoxText = String(v) }
        if let v = result.caseMaterial, !v.isEmpty { caseMaterial = v }
    }

    // MARK: - Save

    private var canSave: Bool {
        let b = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = caliber.trimmingCharacters(in: .whitespacesAndNewlines)
        let g = Int(grainText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return !b.isEmpty && !c.isEmpty && g > 0
    }

    private func save() {
        let b = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let line = productLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = caliber.trimmingCharacters(in: .whitespacesAndNewlines)

        let grain = Int(grainText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let qty = Int(quantityPerBoxText.trimmingCharacters(in: .whitespacesAndNewlines))
        let qtyOrNil: Int? = (qty ?? 0) > 0 ? qty : nil

        let mat = caseMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
        let matOrNil: String? = mat.isEmpty ? nil : mat

        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesOrNil: String? = n.isEmpty ? nil : n

        if let editingAmmo {
            editingAmmo.brand = b
            editingAmmo.productLine = line.isEmpty ? nil : line
            editingAmmo.caliber = c
            editingAmmo.grain = grain
            editingAmmo.bulletTypeRaw = bulletType.rawValue
            editingAmmo.quantityPerBox = qtyOrNil
            editingAmmo.caseMaterial = matOrNil
            editingAmmo.notes = notesOrNil
        } else {
            let a = AmmoProduct(
                brand: b,
                productLine: line.isEmpty ? nil : line,
                caliber: c,
                grain: grain,
                bulletType: bulletType,
                quantityPerBox: qtyOrNil,
                caseMaterial: matOrNil,
                notes: notesOrNil
            )
            modelContext.insert(a)
        }

        dismiss()
    }
}

#Preview {
    AddAmmoView()
}
