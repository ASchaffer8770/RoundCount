//
//  FirearmDetailRouteView.swift
//  RoundCount
//
//  Route wrapper: fetch Firearm by id, then show FirearmDetailView
//

import SwiftUI
import SwiftData

struct FirearmDetailRouteView: View {
    @Environment(\.modelContext) private var modelContext
    let firearmID: PersistentIdentifier

    @State private var firearm: Firearm?

    var body: some View {
        Group {
            if let firearm {
                FirearmDetailView(firearm: firearm)
            } else {
                ContentUnavailableView("Firearm not found", systemImage: "scope")
            }
        }
        .task(id: firearmID) { load() }
    }

    private func load() {
        do {
            firearm = try modelContext.model(for: firearmID) as? Firearm
        } catch {
            firearm = nil
        }
    }
}
