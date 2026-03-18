//
//  BarcodeScannerView.swift
//  RoundCount
//

import SwiftUI
import Vision
import VisionKit

/// Wraps DataScannerViewController. Calls `onScan` with the first barcode payload
/// it detects, then stops scanning. Caller is responsible for dismissing.
struct BarcodeScannerView: UIViewControllerRepresentable {

    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.upce, .ean8, .ean13, .code128, .code39, .itf14])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        guard !context.coordinator.hasStarted else { return }
        context.coordinator.hasStarted = true
        try? uiViewController.startScanning()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        var hasStarted = false
        private var hasFired = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasFired else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let value = barcode.payloadStringValue,
                   !value.isEmpty {
                    hasFired = true
                    dataScanner.stopScanning()
                    onScan(value)
                    return
                }
            }
        }
    }
}

// MARK: - Sheet wrapper with header

struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Scan Barcode")
                    .font(.headline)
                Spacer()
                // Balance the Cancel button width
                Text("Cancel").opacity(0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle().frame(height: 0.5).foregroundStyle(.quaternary),
                alignment: .bottom
            )

            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                BarcodeScannerView { value in
                    onScan(value)
                    dismiss()
                }
                .ignoresSafeArea(edges: .bottom)
            } else {
                ContentUnavailableView(
                    "Scanner Unavailable",
                    systemImage: "barcode.viewfinder",
                    description: Text("Barcode scanning is not available on this device.")
                )
            }
        }
    }
}
