import Foundation
import SwiftData

enum AppRoute: Hashable {
    // Tab root handoffs
    case firearmsIndex
    case ammoIndex

    // Screens
    case analyticsDashboard
    
    // Ammo
    case ammoDetail(PersistentIdentifier)

    // Details
    case firearmDetail(PersistentIdentifier)
    case sessionDetail(UUID) // migrate to PersistentIdentifier later
}
