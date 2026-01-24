import Foundation

enum Feature: String, CaseIterable, Identifiable {
    case unlimitedFirearms
    case maintenanceTracking
    case advancedAnalytics
    case firearmAnalytics
    case dataExport
    case ammoInventory
    case barcodeScan
    case sessionUpgrades
    case firearmSetups
    case magazines

    var id: String { rawValue }

    /// ✅ Only show features that exist in the shipped build
    var isReleased: Bool {
        switch self {
        case .maintenanceTracking, .dataExport, .barcodeScan:
            return false
        default:
            return true
        }
    }

    var title: String {
        switch self {
        case .unlimitedFirearms: return "Unlimited Firearms"
        case .maintenanceTracking: return "Maintenance Tracking"
        case .advancedAnalytics: return "Analytics Dashboard"
        case .firearmAnalytics: return "Firearm Analytics"
        case .dataExport: return "Export (CSV/PDF)"
        case .ammoInventory: return "Ammo Inventory"
        case .barcodeScan: return "Barcode Scanning"
        case .sessionUpgrades: return "Session Upgrades"
        case .firearmSetups: return "Firearm Setups & Gear"
        case .magazines: return "Magazines"
        }
    }

    var description: String {
        switch self {
        case .unlimitedFirearms:
            return "Track all firearms in your safe (no limits)."
        case .maintenanceTracking:
            return "Set round-count and time-based maintenance reminders."
        case .advancedAnalytics:
            return "See trends and breakdowns across all your sessions."
        case .firearmAnalytics:
            return "See trends, averages, and reliability stats for a specific firearm."
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
        case .magazines:
            return "Save magazine capacities per firearm for faster round logging."
        }
    }
}

/// Keep GateResult as a TOP-LEVEL type (production friendly)
enum GateResult {
    case allowed
    case requiresPro(Feature)
    case limitReached(Feature, message: String)
}
