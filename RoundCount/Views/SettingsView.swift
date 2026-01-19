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

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        Text("Tier")
                        Spacer()
                        Text(entitlements.isPro ? "Pro" : "Free")
                            .foregroundStyle(.secondary)
                    }
                }

                if Entitlements.allowBetaProToggle {
                    Section("Beta Tools") {
                        Button {
                            entitlements.setTier(entitlements.isPro ? .free : .pro)
                        } label: {
                            HStack {
                                Text(entitlements.isPro ? "Disable Pro Features (Beta)" : "Enable Pro Features (Beta)")
                                Spacer()
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

