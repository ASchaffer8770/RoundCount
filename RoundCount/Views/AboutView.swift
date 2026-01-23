//
//  AboutView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/22/26.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            Section {
                aboutCard(title: "RoundCount") {
                    Text("""
RoundCount is a private, shooter-first logging tool built for people who care about training, equipment, and progress.

It’s designed to be calm, reliable, and useful over the long term—without accounts, ads, or tracking.
""")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .surfaceCard(radius: Brand.Radius.m)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section {
                aboutCard(title: "Independent Project") {
                    Text("""
RoundCount is built and maintained by an independent solo developer who is also an active member of the community.

Keeping the project small helps it stay focused, private, and intentionally built over time.
""")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .surfaceCard(radius: Brand.Radius.m)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section {
                aboutCard(title: "Privacy Promise") {
                    VStack(alignment: .leading, spacing: 10) {
                        privacyBullet("No account required.")
                        privacyBullet("Sessions, photos, and data stay on your device.")
                        privacyBullet("No tracking. No selling or sharing user data.")
                    }
                    .padding(12)
                    .surfaceCard(radius: Brand.Radius.m)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section {
                aboutCard(title: "Why Pro Exists") {
                    Text("""
Pro helps fund ongoing development while keeping RoundCount independent and free from ads or data monetization.

Upgrading supports the app and unlocks deeper insights for shooters who train regularly.
""")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .surfaceCard(radius: Brand.Radius.m)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Brand.pageBackground(scheme))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Parent Card

    private func aboutCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.s) {
            Text(title)
                .font(Brand.Typography.section)

            content()
        }
        .padding(14)
        .accentCard(radius: Brand.Radius.l)
    }

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Brand.iconAccent(scheme))
                .padding(.top, 1)

            Text(text)
                .foregroundStyle(.secondary)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
