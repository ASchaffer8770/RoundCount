//
//  SettingsView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/18/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var entitlements: Entitlements
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    settingsCard(title: "Account") {
                        settingsRow(
                            title: "Tier",
                            value: entitlements.isPro ? "Pro" : "Free",
                            systemImage: "person.crop.circle"
                        )
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if Entitlements.allowBetaProToggle {
                    Section {
                        settingsCard(title: "Beta Tools") {
                            Button {
                                entitlements.setTier(entitlements.isPro ? .free : .pro)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Brand.iconAccent(scheme))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entitlements.isPro
                                             ? "Disable Pro Features (Beta)"
                                             : "Enable Pro Features (Beta)")
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text("For internal testing only.")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .surfaceCard(radius: Brand.Radius.m)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section {
                    settingsCard(title: "About") {
                        settingsRow(
                            title: "Version",
                            value: appVersion,
                            systemImage: "number"
                        )

                        settingsRow(
                            title: "Build",
                            value: buildNumber,
                            systemImage: "hammer"
                        )
                        Section {
                            settingsCard(title: "About") {

                                NavigationLink {
                                    AboutView()
                                } label: {
                                    settingsRow(
                                        title: "About RoundCount",
                                        value: "",
                                        systemImage: "info.circle"
                                    )
                                }
                                .buttonStyle(.plain)

                                settingsRow(
                                    title: "Version",
                                    value: appVersion,
                                    systemImage: "number"
                                )

                                settingsRow(
                                    title: "Build",
                                    value: buildNumber,
                                    systemImage: "hammer"
                                )
                            }
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Brand.pageBackground(scheme))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Parent Card

    private func settingsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.s) {
            Text(title)
                .font(Brand.Typography.section)

            VStack(spacing: 10) {
                content()
            }
        }
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    // MARK: - Neutral Rows

    private func settingsRow(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Brand.iconAccent(scheme))

            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)

            // tiny alignment affordance
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .opacity(0.55)
        }
        .padding(12)
        .surfaceCard(radius: Brand.Radius.m)
    }
}
