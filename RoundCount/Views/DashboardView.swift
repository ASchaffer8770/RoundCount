//
//  DashboardView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/15/26.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlements: Entitlements
    @State private var showPaywall = false
    @State private var paywallFeature: Feature? = nil
    @State private var gateMessage: String? = nil
    @State private var showGateAlert = false
    @State private var showAnalytics = false
    @State private var showSettings = false

    @Query(sort: \Firearm.createdAt, order: .reverse) private var firearms: [Firearm]
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    @State private var showLog = false
    @State private var showAddFirearm = false

    // MARK: - Derived stats

    private var totalFirearms: Int { firearms.count }

    private var totalRounds: Int {
        firearms.reduce(0) { $0 + $1.totalRounds }
    }

    private var lastSession: Session? { sessions.first }

    private var mostUsedFirearm: Firearm? {
        firearms.max(by: { $0.totalRounds < $1.totalRounds })
    }

    private var recentSessions: [Session] {
        Array(sessions.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    header

                    statsGrid

                    quickActions

                    recentActivity

                    Spacer(minLength: 24)
                }
                .padding()
            }
            .navigationTitle("RoundCount")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }

                    Button {
                        showLog = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }

                    // Keep this ONLY for internal TestFlight / debug.
                    Button(entitlements.isPro ? "Pro: On" : "Pro: Off") {
                        entitlements.setTier(entitlements.isPro ? .free : .pro)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .sheet(isPresented: $showLog) {
                LogSessionView(isModal: true)
            }
            .sheet(isPresented: $showAddFirearm) {
                AddFirearmView()
            }
            .sheet(isPresented: $showAnalytics) {
                NavigationStack {
                    AnalyticsDashboardView()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(sourceFeature: paywallFeature)
                    .environmentObject(entitlements)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(entitlements)
            }

            .alert("Upgrade to Pro", isPresented: $showGateAlert) {
                Button("Not now", role: .cancel) {}
                Button("See Pro") {
                    showPaywall = true
                }
            } message: {
                Text(gateMessage ?? "This feature requires RoundCount Pro.")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dashboard")
                .font(.title.bold())

            if let last = lastSession {
                Text("Last session: \(last.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Log your first session to start tracking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {

                StatCard(title: "Firearms", value: "\(totalFirearms)", systemImage: "scope")

                StatCard(title: "Total rounds", value: "\(totalRounds)", systemImage: "target")

                StatCard(
                    title: "Most used",
                    value: mostUsedFirearm?.displayName ?? "—",
                    systemImage: "flame"
                )

                StatCard(
                    title: "Last session",
                    value: lastSession?.date.formatted(date: .abbreviated, time: .omitted) ?? "—",
                    systemImage: "clock"
                )
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick actions")
                .font(.headline)

            VStack(spacing: 10) {
                Button {
                    showLog = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Log a session")
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.borderedProminent)

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            let result = gateAddFirearm()
                            switch result {
                            case .allowed:
                                showAddFirearm = true
                            case .requiresPro(let feature):
                                paywallFeature = feature
                                showPaywall = true
                            case .limitReached(let feature, let message):
                                gateMessage = message
                                paywallFeature = feature
                                showGateAlert = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "scope")
                                Text("Add firearm")
                                Spacer()
                            }
                            .padding()
                        }
                        .buttonStyle(.bordered)

                        NavigationLink {
                            FirearmsView()
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("View firearms")
                                Spacer()
                            }
                            .padding()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        gateOpenAnalytics()
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Analytics (Pro)")
                            Spacer()
                            if !entitlements.isPro {
                                Image(systemName: "lock.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                    .buttonStyle(.bordered)
                }

            }
        }
    }
    
    private func gateAddFirearm() -> GateResult {
        if entitlements.isPro { return .allowed }

        if firearms.count >= entitlements.freeFirearmLimit {
            return .limitReached(
                .unlimitedFirearms,
                message: "Free tier is limited to \(entitlements.freeFirearmLimit) firearms. Upgrade to Pro for unlimited firearms."
            )
        }

        return .allowed
    }
    
    private func gateOpenAnalytics() {
        if entitlements.isPro {
            showAnalytics = true
            return
        }

        paywallFeature = .advancedAnalytics
        gateMessage = "Analytics is a Pro feature. Upgrade to unlock trends, breakdowns, and performance insights."
        showGateAlert = true
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent activity")
                .font(.headline)

            if recentSessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "doc.text",
                    description: Text("Your recent sessions will show up here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(recentSessions) { s in
                        NavigationLink {
                            FirearmDetailView(firearm: s.firearm)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(s.firearm.displayName)
                                        .font(.headline)
                                    Spacer()
                                    Text(s.date, style: .date)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 10) {
                                    Label("\(s.rounds) rounds", systemImage: "target")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    if let ammo = s.ammo {
                                        Text(ammo.displayName)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                if let notes = s.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Small components

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
