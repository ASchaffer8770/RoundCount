//
//  SessionDetailView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

import SwiftUI
import SwiftData
import UIKit

struct SessionDetailView: View {
    let session: SessionV2

    @State private var selectedPhoto: SessionPhoto? = nil

    /// Photos for this session, sourced directly from the run relationships.
    private var sessionPhotos: [SessionPhoto] {
        session.runs
            .flatMap(\.photos)
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    private var sessionRuns: [FirearmRun] {
        session.runs.sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summaryCard(session: session)

                notesCard(notes: session.notes)

                photosCard(photos: sessionPhotos)

                runsCard(runs: sessionRuns)
            }
            .padding(16)
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPhoto) { p in
            PhotoPreview(photo: p)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { selectedPhoto = nil }
                    }
                }
        }
    }

    // MARK: - Cards

    private func summaryCard(session s: SessionV2) -> some View {
        let duration = s.endedAt.map { max(0, Int($0.timeIntervalSince(s.startedAt))) } ?? 0
        let totalRounds = sessionRuns.reduce(0) { $0 + $1.rounds }
        let totalMalf = sessionRuns.reduce(0) { $0 + $1.malfunctionsCount }

        return card {
            Text("Summary").font(.headline)

            VStack(spacing: 10) {
                row("Started", "\(s.startedAt.formatted(date: .abbreviated, time: .shortened))")
                row("Ended", s.endedAt == nil ? "—" : "\(s.endedAt!.formatted(date: .abbreviated, time: .shortened))")
                row("Duration", formatDuration(TimeInterval(duration)))
                row("Rounds", "\(totalRounds)")
                row("Malfunctions", "\(totalMalf)")
                row("Photos", "\(sessionPhotos.count)")
            }
            .font(.subheadline)
        }
    }

    private func notesCard(notes: String?) -> some View {
        card {
            Text("Notes").font(.headline)

            let text = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                Text("No notes.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                Text(text)
                    .font(.body)
            }
        }
    }

    private func photosCard(photos: [SessionPhoto]) -> some View {
        card {
            HStack {
                Text("Photos").font(.headline)
                Spacer()
                Text("\(photos.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if photos.isEmpty {
                Text("No photos for this session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { p in
                            PhotoThumb(photo: p)
                                .onTapGesture { selectedPhoto = p }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func runsCard(runs: [FirearmRun]) -> some View {
        card {
            HStack {
                Text("Runs").font(.headline)
                Spacer()
                Text("\(runs.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if runs.isEmpty {
                Text("No runs recorded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(runs) { run in
                        RunSummaryCard(run: run)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func row(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left).foregroundStyle(.secondary)
            Spacer()
            Text(right).multilineTextAlignment(.trailing)
        }
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Photo UI

private struct PhotoThumb: View {
    let photo: SessionPhoto

    var body: some View {
        Group {
            // Prefer the stored thumbnail to avoid decoding a full JPEG on the main thread.
            let data = photo.thumbnailData ?? photo.imageData
            if let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.secondary.opacity(0.15))
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 110, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

private struct PhotoPreview: View {
    let photo: SessionPhoto

    var body: some View {
        VStack {
            if let img = UIImage(data: photo.imageData) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.95))
            } else {
                ContentUnavailableView(
                    "Missing photo",
                    systemImage: "photo",
                    description: Text("This photo could not be loaded.")
                )
            }
        }
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Run UI

private struct RunSummaryCard: View {
    let run: FirearmRun

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(run.firearm.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(formatDuration(TimeInterval(run.durationSeconds)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                Text("Rounds: \(run.rounds)")
                Text("•")
                Text("MF: \(run.malfunctionsCount)")
                Text("•")
                Text(run.ammoDisplayLabel.isEmpty ? "Ammo: —" : "Ammo: \(run.ammoDisplayLabel)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if let notes = run.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(notes)
                    .font(.subheadline)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    // Preview requires a live ModelContainer; open SessionDetailView from RouteDestination in practice.
    Text("SessionDetailView — use RouteDestination for preview")
}
