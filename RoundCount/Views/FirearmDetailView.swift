//
//  FirearmDetailView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI
import SwiftData

struct FirearmDetailView: View {
    let firearm: Firearm

    @Query private var sessions: [Session]

    @State private var showEdit = false
    @State private var showLog = false

    init(firearm: Firearm) {
        self.firearm = firearm

        let firearmId = firearm.id   // capture as plain UUID value

        self._sessions = Query(
            filter: #Predicate<Session> { $0.firearm.id == firearmId },
            sort: [SortDescriptor(\Session.date, order: .reverse)]
        )
    }

    var body: some View {
        List {
            Section("Overview") {
                HStack {
                    Text("Firearm")
                    Spacer()
                    Text(firearm.displayName)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Class")
                    Spacer()
                    Text(firearm.firearmClass.rawValue)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Caliber")
                    Spacer()
                    Text(firearm.caliber)
                        .foregroundStyle(.secondary)
                }

                // Serial number (optional)
                if let sn = firearm.serialNumber, !sn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack {
                        Text("Serial")
                        Spacer()
                        Text(sn)
                            .foregroundStyle(.secondary)
                    }
                }

                // Purchase date (optional)
                if let purchased = firearm.purchaseDate {
                    HStack {
                        Text("Purchased")
                        Spacer()
                        Text(purchased.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }

                // Last used date (optional)
                if let lastUsed = firearm.lastUsedDate {
                    HStack {
                        Text("Last used")
                        Spacer()
                        Text(lastUsed.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Total rounds")
                    Spacer()
                    Text("\(firearm.totalRounds)")
                        .foregroundStyle(.secondary)
                }
            }


            Section("Sessions") {
                if sessions.isEmpty {
                    Text("No sessions logged yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { s in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(s.rounds) rounds")
                                    .font(.headline)
                                Spacer()
                                Text(s.date, style: .date)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let ammo = s.ammo {
                                        Text(ammo.displayName)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                            if let notes = s.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        showLog = true
                    } label: {
                        Label("Log", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showLog) {
            LogSessionView(preselectedFirearm: firearm, isModal: true)
        }
        .sheet(isPresented: $showEdit) {
            AddFirearmView(editingFirearm: firearm)
        }
    }
}

