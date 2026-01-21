//
//  AmmoView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/20/26.
//

import SwiftUI
import SwiftData

struct AmmoView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AmmoProduct.createdAt, order: .reverse)
    private var ammo: [AmmoProduct]
    @Query(sort: \FirearmRun.startedAt, order: .reverse)
    private var runs: [FirearmRun]

    @State private var searchText = ""
    @State private var showAdd = false
    @State private var editingAmmo: AmmoProduct? = nil

    // Dashboard
    @State private var dashRange: AnalyticsTimeRange = .days30
    @State private var dashTotals: AmmoDashTotals = .init(rounds: 0, malfunctions: 0, runs: 0)
    @State private var dashRows: [AmmoDashRow] = []

    private var filtered: [AmmoProduct] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return ammo }

        return ammo.filter { a in
            a.displayName.localizedCaseInsensitiveContains(q)
            || a.brand.localizedCaseInsensitiveContains(q)
            || a.caliber.localizedCaseInsensitiveContains(q)
        }
    }

    private var ammoTypesCount: Int { ammo.count }

    private var mostRecentText: String {
        guard let d = ammo.first?.createdAt else { return "—" }
        return d.formatted(date: .abbreviated, time: .omitted)
    }
    
    private func ammoByID(_ id: UUID) -> AmmoProduct? {
        ammo.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection

                // Ammo library
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Ammo",
                        systemImage: "shippingbox",
                        description: Text(searchText.isEmpty
                                          ? "Add the ammo you actually buy so Live sessions can attribute malfunctions to a load."
                                          : "No matches for “\(searchText)”.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    Section("Ammo library") {
                        ForEach(filtered) { a in
                            NavigationLink {
                                AmmoDetailView(ammo: a)
                            } label: {
                                AmmoRow(ammo: a)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    editingAmmo = a
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    modelContext.delete(a)
                                    try? modelContext.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // ✅ Ammo Dashboard directly under library
                ammoDashboardSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ammo")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddAmmoView()
            }
            .sheet(item: $editingAmmo) { a in
                AddAmmoView(editingAmmo: a)
            }
            .onAppear { recomputeDashboard() }
            .onChange(of: dashRange) { _, _ in recomputeDashboard() }
            .onChange(of: ammo.count) { _, _ in recomputeDashboard() }
            .onChange(of: runs.count) { _, _ in recomputeDashboard() }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                summaryPill(title: "Types", value: "\(ammoTypesCount)", systemImage: "tag.fill")
                summaryPill(title: "Last added", value: mostRecentText, systemImage: "clock.fill")
            }
            .padding(.vertical, 4)

            Text("Select ammo in Live runs to compute malfunction rate per ammo type.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Dashboard

    private var ammoDashboardSection: some View {
        Section("Ammo dashboard") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Range")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Range", selection: $dashRange) {
                    ForEach(AnalyticsTimeRange.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    dashPill(title: "Rounds", value: "\(dashTotals.rounds)", systemImage: "target")
                    dashPill(title: "MF", value: "\(dashTotals.malfunctions)", systemImage: "exclamationmark.triangle")
                    dashPill(title: "MF / 1k", value: dashTotals.rounds > 0 ? String(format: "%.1f", dashTotals.malfunctionsPerK) : "—", systemImage: "waveform.path.ecg")
                }
                .padding(.top, 4)

                if dashRows.isEmpty {
                    ContentUnavailableView(
                        "No ammo data yet",
                        systemImage: "tray.fill",
                        description: Text("Start a Live session and select ammo on a run. The dashboard will populate automatically.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(dashRows) { row in
                        if let a = ammoByID(row.id) {
                            NavigationLink {
                                AmmoDetailView(ammo: a)
                            } label: {
                                ammoDashRow(row)
                            }
                        } else {
                            ammoDashRow(row)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func dashPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func ammoDashRow(_ row: AmmoDashRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 10) {
                statChip("Rounds", "\(row.rounds)")
                statChip("MF", "\(row.malfunctions)")
                statChip("MF/1k", row.rounds > 0 ? String(format: "%.1f", row.malfunctionsPerK) : "—")
            }
        }
        .padding(.vertical, 6)
    }

    private func statChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.secondary.opacity(0.10))
        .clipShape(Capsule())
    }

    // MARK: - Compute

    private func recomputeDashboard() {
        let cal = Calendar.current
        let now = Date()
        let start = dashRange.startDate(reference: now, calendar: cal)

        // Fetch runs that have ammo selected
        let descriptor = FetchDescriptor<FirearmRun>(
            predicate: #Predicate<FirearmRun> { $0.ammo != nil },
            sortBy: [SortDescriptor(\FirearmRun.startedAt, order: .reverse)]
        )

        let runs: [FirearmRun]
        do {
            runs = try modelContext.fetch(descriptor)
        } catch {
            print("❌ Ammo dashboard fetch runs failed: \(error)")
            dashTotals = .init(rounds: 0, malfunctions: 0, runs: 0)
            dashRows = []
            return
        }

        // Filter by time range
        let filteredRuns: [FirearmRun]
        if let start {
            filteredRuns = runs.filter { $0.startedAt >= start }
        } else {
            filteredRuns = runs
        }

        // Aggregate by ammo.id
        var totalsRounds = 0
        var totalsMF = 0

        var map: [UUID: (title: String, rounds: Int, mf: Int)] = [:]
        map.reserveCapacity(min(64, ammo.count))

        for r in filteredRuns {
            guard let a = r.ammo else { continue }

            totalsRounds += r.rounds
            totalsMF += r.malfunctionsCount

            let id = a.id
            let title = a.displayName

            if map[id] == nil {
                map[id] = (title: title, rounds: r.rounds, mf: r.malfunctionsCount)
            } else {
                map[id]!.rounds += r.rounds
                map[id]!.mf += r.malfunctionsCount
            }
        }

        var rows: [AmmoDashRow] = []
        rows.reserveCapacity(map.count)
        for (id, v) in map {
            rows.append(.init(id: id, title: v.title, rounds: v.rounds, malfunctions: v.mf))
        }

        // Sort: most rounds first (then MF)
        rows.sort {
            if $0.rounds != $1.rounds { return $0.rounds > $1.rounds }
            return $0.malfunctions > $1.malfunctions
        }

        dashTotals = .init(rounds: totalsRounds, malfunctions: totalsMF, runs: filteredRuns.count)
        dashRows = rows
    }
}

// MARK: - Row UI

private struct AmmoRow: View {
    let ammo: AmmoProduct

    private var subtitleParts: [String] {
        var parts: [String] = []
        parts.append(ammo.caliber)
        parts.append("\(ammo.grain)gr")
        parts.append(ammo.bulletTypeRaw)

        if let qty = ammo.quantityPerBox, qty > 0 {
            parts.append("\(qty)/box")
        }

        if let mat = ammo.caseMaterial?.trimmingCharacters(in: .whitespacesAndNewlines),
           !mat.isEmpty {
            parts.append(mat)
        }

        return parts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let line = (ammo.productLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            let title = line.isEmpty ? ammo.brand : "\(ammo.brand) \(line)"

            Text(title)
                .font(.headline)
                .lineLimit(1)

            Text(subtitleParts.joined(separator: " • "))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let notes = ammo.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dashboard Models (local to this file)

private struct AmmoDashRow: Identifiable, Hashable {
    let id: UUID               // ammo.id
    let title: String          // ammo.displayName
    let rounds: Int
    let malfunctions: Int

    var malfunctionsPerK: Double {
        guard rounds > 0 else { return 0 }
        return (Double(malfunctions) / Double(rounds)) * 1000.0
    }
}

private struct AmmoDashTotals: Hashable {
    let rounds: Int
    let malfunctions: Int
    let runs: Int

    var malfunctionsPerK: Double {
        guard rounds > 0 else { return 0 }
        return (Double(malfunctions) / Double(rounds)) * 1000.0
    }
}

#Preview {
    AmmoView()
}
