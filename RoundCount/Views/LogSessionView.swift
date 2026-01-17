import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct LogSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlements: Entitlements

    @Query(sort: \Firearm.createdAt, order: .reverse) private var firearms: [Firearm]

    // Preselect support
    private let preselectedFirearm: Firearm?
    private let isModal: Bool

    // Form state
    @State private var selectedFirearm: Firearm?
    @State private var roundsText: String = ""
    @State private var sessionDate: Date = Date()
    @State private var notes: String = ""
    @State private var selectedAmmo: AmmoProduct?
    @State private var showAmmoPicker = false

    // ✅ Session v2 (Pro)
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 0

    @State private var malfunctionDraft = MalfunctionDraft()
    @State private var showMalfunctionEditor = false

    // Photos (Pro)
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var pendingPhotoData: [Data] = []

    // UI state
    @State private var showAddFirearm = false
    @State private var showToast = false
    @State private var toastText = "Session logged"
    @State private var selectedSetup: FirearmSetup?
    @State private var showPaywall = false

    init(preselectedFirearm: Firearm? = nil, isModal: Bool = false) {
        self.preselectedFirearm = preselectedFirearm
        self.isModal = isModal
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Firearm") {
                    if firearms.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a firearm to log sessions.")
                                .foregroundStyle(.secondary)
                            Button("Add Firearm") { showAddFirearm = true }
                        }
                    } else if firearms.count == 1 {
                        HStack {
                            Text("Selected")
                            Spacer()
                            Text(firearms[0].displayName).foregroundStyle(.secondary)
                        }
                        .onAppear { selectedFirearm = firearms[0] }
                        .onChange(of: firearms.map(\.id)) { _, _ in
                            if selectedFirearm == nil {
                                selectedFirearm = preselectedFirearm ?? firearms.first
                            }
                        }

                    } else {
                        Picker("Firearm", selection: $selectedFirearm) {
                            Text("Select…").tag(Optional<Firearm>.none)
                            ForEach(firearms) { f in
                                Text(f.displayName).tag(Optional(f))
                            }
                        }
                    }
                }
                
                setupSection

                Section("Ammo (optional)") {
                    Button {
                        showAmmoPicker = true
                    } label: {
                        HStack {
                            Text("Select Ammo")
                            Spacer()
                            Text(selectedAmmo?.displayName ?? "None")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if selectedAmmo != nil {
                        Button(role: .destructive) {
                            selectedAmmo = nil
                        } label: {
                            Text("Clear Ammo")
                        }
                    }
                }

                Section("Rounds Fired") {
                    TextField("Enter rounds…", text: $roundsText)
                        .keyboardType(.numberPad)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach([10, 25, 50, 100, 150, 200], id: \.self) { v in
                                Button("\(v)") { roundsText = "\(v)" }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                // ✅ Pro: Session Upgrades (v2)
                Section("Session Upgrades") {
                    if entitlements.isPro {
                        rangeTimeRow
                        malfunctionRow
                        photosRow
                    } else {
                        proLockedRow(
                            title: "Pro Session Upgrades",
                            subtitle: "Add photos, track malfunctions, and log total range time."
                        )
                        PaywallView(sourceFeature: .sessionUpgrades)
                    }
                }

                Section("Magazines Used") {
                    // Placeholder (future)
                    HStack {
                        Text("Magazines Used")
                        Spacer()
                        Text("Not tracking yet")
                            .foregroundStyle(.secondary)
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                    Text("Magazine tracking is coming soon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Date & Time") {
                    DatePicker("When", selection: $sessionDate)
                }

                Section("Notes (optional)") {
                    TextField("Notes…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Log Session")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isModal {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .overlay(alignment: .top) {
                if showToast {
                    Text(toastText)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showToast)
            .safeAreaInset(edge: .bottom) {
                saveBar
            }
            .sheet(isPresented: $showAddFirearm) {
                AddFirearmView()
            }
            .sheet(isPresented: $showAmmoPicker) {
                AmmoPickerView(selectedAmmo: $selectedAmmo)
            }
            .sheet(isPresented: $showMalfunctionEditor) {
                MalfunctionEditorView(draft: $malfunctionDraft)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(sourceFeature: .firearmSetups)
            }
            .onAppear {
                // Prioritize preselected firearm (if present)
                if selectedFirearm == nil {
                    if let pre = preselectedFirearm {
                        selectedFirearm = pre
                    } else {
                        selectedFirearm = firearms.first
                    }
                }
            }
            .onChange(of: photoPickerItems) { _, newItems in
                guard entitlements.isPro else { return }
                Task { await loadPickedPhotos(newItems) }
            }
            .onChange(of: selectedFirearm?.id) { _, _ in
                guard entitlements.isPro else { return }
                if let firearm = selectedFirearm {
                    selectedSetup = firearm.setups.first(where: { $0.isActive }) ?? firearm.setups.first
                } else {
                    selectedSetup = nil
                }
            }
        }
    }
    
    private var setupSection: some View {
        Section("Setup") {
            if entitlements.isPro {
                if let firearm = selectedFirearm {
                    setupPicker(for: firearm)
                } else {
                    Text("Select a firearm first.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button { showPaywall = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Track Setup Used")
                            Text("Log sessions against firearm setups (optic/light/etc.).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func setupPicker(for firearm: Firearm) -> some View {
        let setups = setupsFor(firearm)

        if setups.isEmpty {
            Text("No setups for this firearm yet.")
                .foregroundStyle(.secondary)
        } else {
            Picker("Setup", selection: $selectedSetup) {
                Text("Select…").tag(Optional<FirearmSetup>.none)
                ForEach(setups) { s in
                    Text(s.isActive ? "\(s.name) (Active)" : s.name)
                        .tag(Optional(s))
                }
            }
        }
    }

    
    // MARK: - Pro UI rows

    private var rangeTimeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Total Range Time")
                Spacer()
                Text(formattedDuration(hours: durationHours, minutes: durationMinutes))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Picker("Hours", selection: $durationHours) {
                    ForEach(0..<13, id: \.self) { Text("\($0)h").tag($0) }
                }
                .pickerStyle(.menu)

                Picker("Minutes", selection: $durationMinutes) {
                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) {
                        Text("\($0)m").tag($0)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var malfunctionRow: some View {
        Button {
            showMalfunctionEditor = true
        } label: {
            HStack {
                Text("Malfunctions")
                Spacer()
                Text(malfunctionDraft.isAllZero ? "None" : "\(malfunctionDraft.total)")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var photosRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Session Photos")
                Spacer()
                Text(pendingPhotoData.isEmpty ? "None" : "\(pendingPhotoData.count)")
                    .foregroundStyle(.secondary)
            }

            PhotosPicker(
                selection: $photoPickerItems,
                maxSelectionCount: 8,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Add Photos")
                }
            }

            if !pendingPhotoData.isEmpty {
                Button(role: .destructive) {
                    pendingPhotoData.removeAll()
                    photoPickerItems.removeAll()
                } label: {
                    Text("Clear Photos")
                }
            }
        }
    }

    private func proLockedRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            }
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        VStack {
            Divider()
            Button {
                saveSession()
            } label: {
                Text("Save Session")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
            .padding()
        }
        .background(.ultraThinMaterial)
    }

    private var canSave: Bool {
        selectedFirearm != nil && (Int(roundsText) ?? 0) >= 1
    }

    private func saveSession() {
        guard let firearm = selectedFirearm,
              let rounds = Int(roundsText),
              rounds >= 1
        else { return }

        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let session = Session(
            firearm: firearm,
            ammo: selectedAmmo,
            rounds: rounds,
            date: sessionDate,
            notes: trimmed.isEmpty ? nil : trimmed,
            durationSeconds: entitlements.isPro ? computedDurationSeconds : nil,
            malfunctions: nil,
            setup: entitlements.isPro ? selectedSetup : nil
        )

        // Pro: malfunctions
        if entitlements.isPro, !malfunctionDraft.isAllZero {
            let m = MalfunctionSummary(
                failureToFeed: malfunctionDraft.failureToFeed,
                failureToEject: malfunctionDraft.failureToEject,
                stovepipe: malfunctionDraft.stovepipe,
                doubleFeed: malfunctionDraft.doubleFeed,
                lightStrike: malfunctionDraft.lightStrike,
                other: malfunctionDraft.other
            )
            session.malfunctions = m
        }

        modelContext.insert(session)
        firearm.totalRounds += rounds

        // Pro: photos (local-only)
        if entitlements.isPro, !pendingPhotoData.isEmpty {
            for jpeg in pendingPhotoData {
                let photoId = UUID()
                do {
                    let relPath = try PhotoStore.saveJPEGForSession(
                        sessionId: session.id,
                        photoId: photoId,
                        jpegData: jpeg
                    )
                    let photo = SessionPhoto(
                        id: photoId,
                        createdAt: .now,
                        relativePath: relPath,
                        caption: nil
                    )
                    session.photos.append(photo)
                } catch {
                    // Non-fatal: keep the session even if a photo save fails
                }
            }
        }

        // Reset for fast follow-up logs
        roundsText = ""
        notes = ""
        sessionDate = Date()
        selectedAmmo = nil

        // Reset Pro state
        durationHours = 0
        durationMinutes = 0
        malfunctionDraft = MalfunctionDraft()
        pendingPhotoData.removeAll()
        photoPickerItems.removeAll()

        // Toast
        toastText = "Session logged"
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showToast = false
        }

        // Auto-dismiss only when presented modally
        if isModal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private var computedDurationSeconds: Int? {
        let totalMinutes = (durationHours * 60) + durationMinutes
        return totalMinutes > 0 ? totalMinutes * 60 : nil
    }

    private func formattedDuration(hours: Int, minutes: Int) -> String {
        let totalMinutes = (hours * 60) + minutes
        if totalMinutes == 0 { return "None" }
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        pendingPhotoData.removeAll()

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data),
                   let jpeg = uiImage.jpegData(compressionQuality: 0.85) {
                    pendingPhotoData.append(jpeg)
                } else {
                    pendingPhotoData.append(data)
                }
            }
        }
    }
    
    private func setupsFor(_ firearm: Firearm) -> [FirearmSetup] {
        firearm.setups.sorted {
            if $0.isActive != $1.isActive { return $0.isActive && !$1.isActive }
            return $0.createdAt > $1.createdAt
        }
    }

}
