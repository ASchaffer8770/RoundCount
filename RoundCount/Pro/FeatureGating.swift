//
//  FeatureGating.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import Foundation
import Combine

enum Feature: String, CaseIterable, Identifiable {
    case unlimitedFirearms
    case maintenanceTracking
    case advancedAnalytics
    case dataExport
    case ammoInventory
    case barcodeScan
    case sessionUpgrades
    case firearmSetups

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedFirearms: return "Unlimited Firearms"
        case .maintenanceTracking: return "Maintenance Tracking"
        case .advancedAnalytics: return "Advanced Stats"
        case .dataExport: return "Export (CSV/PDF)"
        case .ammoInventory: return "Ammo Inventory"
        case .barcodeScan: return "Barcode Scanning"
        case .sessionUpgrades: return "Session Upgrades"
        case .firearmSetups: return "Firearm Setups & Gear"
        }
    }

    var description: String {
        switch self {
        case .unlimitedFirearms:
            return "Track all firearms in your safe (no limits)."
        case .maintenanceTracking:
            return "Set round-count and time-based maintenance reminders."
        case .advancedAnalytics:
            return "See deeper insights across firearms, ammo, and sessions."
        case .dataExport:
            return "Export your firearms and sessions for backup or records."
        case .ammoInventory:
            return "Track boxes owned and auto-decrement rounds as you log."
        case .barcodeScan:
            return "Scan ammo barcodes to quickly add products and inventory."
        case .sessionUpgrades:
            return "Add photos, track malfunctions, and log total range time."
        case .firearmSetups:
            return "Create setups per firearm (optic/light/etc.) and track battery life."
        }
    }
}

enum GateResult {
    case allowed
    case requiresPro(Feature)
    case limitReached(Feature, message: String)
}
