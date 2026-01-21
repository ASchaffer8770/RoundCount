//
//  AppTabRouter.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/20/26.
//

//
//  AppTabRouter.swift
//  RoundCount
//

import Foundation
import SwiftUI
import Combine

enum AppTab: Hashable {
    case dashboard
    case firearms
    case ammo
    case live
    case settings
}

@MainActor
final class AppTabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard

    /// One-shot request: LiveSessionView consumes it and clears it.
    @Published var pendingLiveFirearmID: UUID? = nil

    func startLive(for firearmID: UUID) {
        pendingLiveFirearmID = firearmID
        selectedTab = .live
    }

    func clearPendingLiveRequest() {
        pendingLiveFirearmID = nil
    }
}
