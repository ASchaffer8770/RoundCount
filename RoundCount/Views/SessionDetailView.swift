//
//  SessionDetailView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @EnvironmentObject private var entitlements: Entitlements

    var body: some View {
        List {
            Section("Overview") {
                row("Firearm", session.firearm.displayName)
                row("Date", session.date.formatted(date: .abbreviated, time: .shortened))
                row("Rounds", "\(session.rounds)")

                if let ammo = session.ammo {
                    row("Ammo", ammo.displayName)
                }
            }

            // Pro: Range time
            Section("Range Time") {
                if entitlements.isPro {
                    row("Total", formattedDuration(seconds: session.durationSeconds))
                } else {
                    lockedRow("Total range time is a Pro feature.")
                }
            }

            // Pro: Malfunctions
            Section("Malfunctions") {
                if entitlements.isPro {
                    if let m = session.malfunctions, m.total > 0 {
                        malfunctionRow("Failure to Feed", m.failureToFeed)
                        malfunctionRow("Failure to Eject", m.failureToEject)
                        malfunctionRow("Stovepipe", m.stovepipe)
                        malfunctionRow("Double Feed", m.doubleFeed)
                        malfunctionRow("Light Strike", m.lightStrike)
                        malfunctionRow("Other", m.other)

                        HStack {
                            Text("Total")
                            Spacer()
                            Text("\(m.total)").foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No malfunctions recorded.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    lockedRow("Malfunction tracking is a Pro feature.")
                }
            }

            // Pro: Photos
            Section("Photos") {
                if entitlements.isPro {
                    if session.photos.isEmpty {
                        Text("No photos added.")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(session.photos) { p in
                                    SessionPhotoThumb(photo: p)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                } else {
                    lockedRow("Session photos are a Pro feature.")
                }
            }

            // Notes
            Section("Notes") {
                if let notes = session.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(notes)
                } else {
                    Text("No notes.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Session")
    }

    // MARK: - UI helpers

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func lockedRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }

    private func malfunctionRow(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .opacity(count == 0 ? 0.5 : 1.0)
    }

    private func formattedDuration(seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "None" }
        let totalMinutes = seconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}

private struct SessionPhotoThumb: View {
    let photo: SessionPhoto

    var body: some View {
        Group {
            if let img = PhotoStore.loadImage(relativePath: photo.relativePath) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

