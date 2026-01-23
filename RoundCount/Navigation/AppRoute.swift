import Foundation
import SwiftData

enum AppRoute: Hashable {
    // Tab root handoffs
    case firearmsIndex
    case ammoIndex

    // Screens
    case analyticsDashboard

    // Details
    case firearmDetail(PersistentIdentifier)
    case sessionDetail(UUID) // migrate to PersistentIdentifier later
}
