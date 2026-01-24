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
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var router: AppRouter

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

    private func openAddAmmo() { showAdd = true }

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
        List {
            // MARK: Summary (parent card)
            Section {
                VStack(alignment: .leading, spacing: Brand.Spacing.s) {
                    HStack(spacing: 12) {
                        summaryPill(
                            title: "Types",
                            value: "\(ammoTypesCount)",
                            systemImage: "tag.fill"
                        )

                        summaryPill(
                            title: "Last added",
                            value: mostRecentText,
                            systemImage: "clock.fill"
                        )
                    }

                    Text("Select ammo in Live runs to compute malfunction rate per ammo type.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .accentCard(radius: Brand.Radius.l)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // MARK: Ammo library (parent card)
            Section {
                VStack(alignment: .leading, spacing: Brand.Spacing.s) {

                    // Header + Add button (✅ always available)
                    HStack(spacing: 10) {
                        Text("Ammo library")
                            .font(Brand.Typography.section)

                        Spacer()

                        Button {
                            openAddAmmo()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.semibold))
                                Text("Add")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Brand.accent.opacity(scheme == .dark ? 0.18 : 0.12))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Brand.accent.opacity(scheme == .dark ? 0.35 : 0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "No Ammo",
                                systemImage: "shippingbox",
                                description: Text(searchText.isEmpty
                                                  ? "Add the ammo you actually buy so Live sessions can attribute malfunctions to a load."
                                                  : "No matches for “\(searchText)”.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)

                            // ✅ Primary CTA (fresh install fix)
                            Button {
                                openAddAmmo()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                    Text("Add Ammo")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding(12)
                            }
                            .buttonStyle(.plain)
                            .surfaceCard(radius: Brand.Radius.m)
                        }
                        .surfaceCard(radius: Brand.Radius.m)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filtered) { a in
                                Button {
                                    router.ammoPath.append(.ammoDetail(a.persistentModelID))
                                } label: {
                                    HStack(spacing: 12) {
                                        AmmoRow(ammo: a)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .surfaceCard(radius: Brand.Radius.m)
                                    .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.m, style: .continuous))
                                }
                                .buttonStyle(.plain)
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
                }
                .padding(14)
                .accentCard(radius: Brand.Radius.l)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // MARK: Ammo Dashboard (parent card)
            Section {
                ammoDashboardCard
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Brand.pageBackground(scheme))
        .navigationTitle("Ammo")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))

        // Sheets
        .sheet(isPresented: $showAdd) { AddAmmoView() }
        .sheet(item: $editingAmmo) { a in AddAmmoView(editingAmmo: a) }

        // Recompute dashboard
        .onAppear { recomputeDashboard() }
        .onChange(of: dashRange) { _, _ in recomputeDashboard() }
        .onChange(of: ammo.count) { _, _ in recomputeDashboard() }
        .onChange(of: runs.count) { _, _ in recomputeDashboard() }
    }

    // MARK: - Summary pill (inner card)

    private func summaryPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Brand.iconAccent(scheme))

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
        .surfaceCard(radius: Brand.Radius.m)
    }

    // MARK: - Dashboard card (parent)

    private var ammoDashboardCard: some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.s) {
            HStack {
                Text("Ammo dashboard")
                    .font(Brand.Typography.section)
                Spacer()
            }

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
                dashPill(
                    title: "MF / 1k",
                    value: dashTotals.rounds > 0 ? String(format: "%.1f", dashTotals.malfunctionsPerK) : "—",
                    systemImage: "waveform.path.ecg"
                )
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
                .surfaceCard(radius: Brand.Radius.m)
            } else {
                VStack(spacing: 10) {
                    ForEach(dashRows) { row in
                        if let a = ammoByID(row.id) {
                            Button {
                                router.ammoPath.append(.ammoDetail(a.persistentModelID))
                            } label: {
                                HStack(spacing: 12) {
                                    ammoDashRow(row)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .surfaceCard(radius: Brand.Radius.m)
                                .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.m, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
                            ammoDashRow(row)
                                .padding(12)
                                .surfaceCard(radius: Brand.Radius.m)
                        }
                    }
                }
            }
        }
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    // MARK: - Dashboard inner pill (inner card)

    private func dashPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Brand.iconAccent(scheme))

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
        .surfaceCard(radius: Brand.Radius.m)
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
                Spacer(minLength: 0)
            }
        }
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
        .background(Brand.accent.opacity(scheme == .dark ? 0.12 : 0.10))
        .clipShape(Capsule())
    }

    // MARK: - Compute

    private func recomputeDashboard() {
        let cal = Calendar.current
        let now = Date()
        let start = dashRange.startDate(reference: now, calendar: cal)

        let descriptor = FetchDescriptor<FirearmRun>(
            predicate: #Predicate<FirearmRun> { $0.ammo != nil },
            sortBy: [SortDescriptor(\FirearmRun.startedAt, order: .reverse)]
        )

        let fetchedRuns: [FirearmRun]
        do {
            fetchedRuns = try modelContext.fetch(descriptor)
        } catch {
            print("❌ Ammo dashboard fetch runs failed: \(error)")
            dashTotals = .init(rounds: 0, malfunctions: 0, runs: 0)
            dashRows = []
            return
        }

        let filteredRuns: [FirearmRun] = {
            if let start { return fetchedRuns.filter { $0.startedAt >= start } }
            return fetchedRuns
        }()

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
    }
}

// MARK: - Dashboard Models (local to this file)

private struct AmmoDashRow: Identifiable, Hashable {
    let id: UUID
    let title: String
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
