import SwiftUI
import SwiftData

struct AmmoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let ammo: AmmoProduct

    // Pull runs so we can compute usage. (In-memory filter is fine for v1.)
    @Query(sort: \FirearmRun.startedAt, order: .reverse) private var allRuns: [FirearmRun]

    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    // MARK: - Usage rollups

    private var runsUsingAmmo: [FirearmRun] {
        allRuns.filter { $0.ammo?.id == ammo.id }
    }

    private var runsDefaultingToAmmo: [FirearmRun] {
        allRuns.filter { $0.defaultAmmo?.id == ammo.id && $0.ammo?.id != ammo.id }
    }

    private var totalRuns: Int { runsUsingAmmo.count }
    private var totalRounds: Int { runsUsingAmmo.reduce(0) { $0 + $1.rounds } }
    private var totalMalfunctions: Int { runsUsingAmmo.reduce(0) { $0 + $1.malfunctionsCount } }

    private var sessionsUsingAmmo: [SessionV2] {
        // Unique sessions, newest first by startedAt
        let sessions = Dictionary(grouping: runsUsingAmmo, by: { $0.session.id })
            .values
            .compactMap { $0.first?.session }
        return sessions.sorted(by: { $0.startedAt > $1.startedAt })
    }

    private var lastUsedAt: Date? { runsUsingAmmo.first?.startedAt }

    // MARK: - View

    var body: some View {
        List {
            headerSection
            detailsSection
            usageSection

            if !runsDefaultingToAmmo.isEmpty {
                defaultAmmoSection
            }

            recentRunsSection
            notesSection
            actionsSection
        }
        .navigationTitle("Ammo")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this ammo?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteAmmo() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes it from your ammo library. Existing runs will keep their round counts, but ammo references will be cleared.")
        }
        .sheet(isPresented: $showEditSheet) {
            AmmoEditView(ammo: ammo)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(ammoTitle)
                    .font(.headline)

                Text(ammo.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    pill(ammo.caliber)
                    pill("\(ammo.grain) gr")
                    pill(ammo.bulletType.rawValue)

                    if let q = ammo.quantityPerBox, q > 0 {
                        pill("\(q) / box")
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            statRow("Brand", value: ammo.brand)
            statRow("Product Line", value: (ammo.productLine.nonEmpty ?? "—"))
            statRow("Caliber", value: ammo.caliber)
            statRow("Grain", value: "\(ammo.grain)")
            statRow("Bullet Type", value: ammo.bulletType.rawValue)
            statRow("Case", value: (ammo.caseMaterial.nonEmpty ?? "—"))
            statRow("Added", value: ammo.createdAt.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private var usageSection: some View {
        Section("Usage (Selected Ammo)") {
            statRow("Runs", value: "\(totalRuns)")
            statRow("Sessions", value: "\(sessionsUsingAmmo.count)")
            statRow("Total rounds", value: totalRounds > 0 ? "\(totalRounds)" : "—")
            statRow("Malfunctions", value: totalMalfunctions > 0 ? "\(totalMalfunctions)" : "—")
            statRow("Last used", value: lastUsedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
        }
    }

    private var defaultAmmoSection: some View {
        Section("Used as Default Ammo") {
            Text("These runs had this ammo set as the default, but a different ammo may have been selected during the run.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            statRow("Runs", value: "\(runsDefaultingToAmmo.count)")
        }
    }

    private var recentRunsSection: some View {
        Section("Recent Runs") {
            if runsUsingAmmo.isEmpty {
                Text("No runs logged with this ammo yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(runsUsingAmmo.prefix(12)) { run in
                    runRow(run)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            if let notes = ammo.notes.nonEmpty {
                Text(notes)
                    .foregroundStyle(.secondary)
            } else {
                Text("No notes.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                showEditSheet = true
            } label: {
                Label("Edit Ammo", systemImage: "pencil")
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete Ammo", systemImage: "trash")
            }
        }
    }

    // MARK: - Rows / helpers

    private func runRow(_ run: FirearmRun) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.firearm.displayName)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(run.session.startedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(run.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Rounds: \(run.rounds)")
                Text("•")
                Text("MF: \(run.malfunctionsCount)")
                Text("•")
                Text("Time: \(formatDuration(TimeInterval(run.durationSeconds)))")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let notes = run.notes.nonEmpty {
                Text(notes).font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private var ammoTitle: String {
        let line = ammo.productLine.nonEmpty
        return line == nil ? ammo.brand : "\(ammo.brand) \(line!)"
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }

    private func statRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func deleteAmmo() {
        // Clear references first to avoid dangling pointers in UI,
        // and to make behavior predictable for analytics trust.
        for r in allRuns {
            if r.ammo?.id == ammo.id { r.ammo = nil }
            if r.defaultAmmo?.id == ammo.id { r.defaultAmmo = nil }
        }

        modelContext.delete(ammo)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Helpers (single source of truth)

private extension String {
    var nonEmpty: String? {
        let s = trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        switch self {
        case .none: return nil
        case .some(let s): return s.nonEmpty
        }
    }
}
