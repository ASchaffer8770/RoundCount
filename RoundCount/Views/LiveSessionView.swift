//
//  LiveSessionView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/19/26.
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI
import Combine

// MARK: - ViewModel (SwiftData-backed)

@MainActor
final class LiveSessionVM: ObservableObject {

    enum State: Equatable { case idle, running, paused, ended }

    @Published var state: State = .idle
    @Published var startedAt: Date? = nil
    @Published var endedAt: Date? = nil

    @Published private(set) var elapsedCarry: TimeInterval = 0
    private var resumeAnchor: Date? = nil

    @Published var now: Date = Date()
    private var timer: Timer?

    @Published var session: SessionV2? = nil
    @Published var runs: [FirearmRun] = []
    @Published var activeRunID: UUID? = nil
    @Published var sessionNotes: String = ""

    var totalRounds: Int { runs.reduce(0) { $0 + $1.rounds } }
    var totalMalfunctions: Int { runs.reduce(0) { $0 + $1.malfunctionsCount } }

    var sessionDuration: TimeInterval {
        switch state {
        case .running:
            let anchor = resumeAnchor ?? startedAt ?? now
            return max(0, elapsedCarry + now.timeIntervalSince(anchor))
        case .paused, .ended:
            return max(0, elapsedCarry)
        case .idle:
            return 0
        }
    }

    var activeRunIndex: Int? {
        guard let id = activeRunID else { return nil }
        return runs.firstIndex(where: { $0.id == id })
    }

    var activeRun: FirearmRun? {
        guard let idx = activeRunIndex else { return nil }
        return runs[idx]
    }

    // MARK: Save strategy
    // Keep taps/snappy UI: never block a gesture on a synchronous save.
    private func scheduleSave(_ modelContext: ModelContext) {
        Task { @MainActor in
            try? modelContext.save()
        }
    }

    // MARK: Lifecycle

    func startSession(modelContext: ModelContext) {
        guard state == .idle else { return }

        let s = SessionV2(startedAt: Date(), endedAt: nil, notes: nil)
        modelContext.insert(s)

        session = s
        startedAt = s.startedAt
        elapsedCarry = 0
        resumeAnchor = startedAt
        endedAt = s.endedAt
        sessionNotes = s.notes ?? ""

        runs = []
        activeRunID = nil

        state = .running
        startTimer()
    }


    func pauseSession(modelContext: ModelContext) {
        guard state == .running else { return }
        state = .paused
        stopTimer()
        endActiveRunIfNeeded(modelContext: modelContext)
        if let anchor = resumeAnchor {
            elapsedCarry += now.timeIntervalSince(anchor)
        }
        resumeAnchor = nil
    }

    func resumeSession() {
        guard state == .paused else { return }
        state = .running
        resumeAnchor = Date()
        startTimer()
    }

    func endSession(modelContext: ModelContext) {
        guard state == .running || state == .paused else { return }
        if state == .running { endActiveRunIfNeeded(modelContext: modelContext) }
        guard let s = session else { return }

        if state == .running, let anchor = resumeAnchor {
            elapsedCarry += now.timeIntervalSince(anchor)
        }
        resumeAnchor = nil

        s.endedAt = Date()
        s.notes = sessionNotes

        try? modelContext.save()   // ✅ OK to block here; user expects a “finish/save”
        endedAt = s.endedAt
        state = .ended
        stopTimer()
    }

    func resetSession() {
        stopTimer()
        elapsedCarry = 0
        resumeAnchor = nil
        state = .idle
        startedAt = nil
        endedAt = nil
        session = nil
        runs = []
        activeRunID = nil
        sessionNotes = ""
        now = Date()
    }

    // MARK: Runs

    func startNewRun(modelContext: ModelContext, firearm: Firearm) {
        guard state == .running else { return }
        guard let s = session else { return }

        endActiveRunIfNeeded(modelContext: modelContext)

        let run = FirearmRun(
            firearm: firearm,
            startedAt: Date(),
            endedAt: nil,
            rounds: 0,
            malfunctionsCount: 0,
            notes: nil,
            session: s,
            selectedMagazine: firearm.magazines.sorted(by: { $0.capacity < $1.capacity }).first
        )

        modelContext.insert(run)
        s.runs.append(run)

        // ✅ Update UI immediately
        runs = s.runs.sorted(by: { $0.startedAt < $1.startedAt })
        activeRunID = run.id
        objectWillChange.send()

        // ✅ Save deferred
        scheduleSave(modelContext)
    }

    func continueRun(from priorRunID: UUID, modelContext: ModelContext) {
        guard state == .running else { return }
        guard let s = session else { return }
        guard let prior = runs.first(where: { $0.id == priorRunID }) else { return }

        endActiveRunIfNeeded(modelContext: modelContext)

        let newRun = FirearmRun(
            firearm: prior.firearm,
            startedAt: Date(),
            endedAt: nil,
            rounds: 0,
            malfunctionsCount: 0,
            notes: nil,
            session: s,
            selectedMagazine: prior.selectedMagazine
        )

        newRun.ammo = prior.ammo
        newRun.defaultAmmo = prior.defaultAmmo

        modelContext.insert(newRun)
        s.runs.append(newRun)

        // ✅ Update UI immediately
        runs = s.runs.sorted(by: { $0.startedAt < $1.startedAt })
        activeRunID = newRun.id
        objectWillChange.send()

        // ✅ Save deferred
        scheduleSave(modelContext)
    }

    func endActiveRunIfNeeded(modelContext: ModelContext) {
        guard let idx = activeRunIndex else { return }
        let run = runs[idx]
        if run.endedAt == nil {
            run.endedAt = Date()
            // ✅ Save deferred
            scheduleSave(modelContext)
        }
        activeRunID = nil
        objectWillChange.send()
    }

    func updateRun(_ runID: UUID, modelContext: ModelContext, mutate: (FirearmRun) -> Void) {
        guard let run = runs.first(where: { $0.id == runID }) else { return }
        mutate(run)
        objectWillChange.send()
    }

    func deleteRun(_ runID: UUID, modelContext: ModelContext) {
        if activeRunID == runID { activeRunID = nil }
        guard let run = runs.first(where: { $0.id == runID }) else { return }

        if let s = session { s.runs.removeAll(where: { $0.id == runID }) }
        modelContext.delete(run)

        if let s = session {
            runs = s.runs.sorted(by: { $0.startedAt < $1.startedAt })
        } else {
            runs.removeAll(where: { $0.id == runID })
        }
        objectWillChange.send()

        // ✅ Save deferred
        scheduleSave(modelContext)
    }

    func updateSessionNotes(modelContext: ModelContext, notes: String) {
        sessionNotes = notes
        session?.notes = notes
        // ✅ Save deferred while typing
        scheduleSave(modelContext)
        objectWillChange.send()
    }

    // MARK: Malfunctions (persisted per kind)

    func bumpMalfunction(runID: UUID, kind: MalfunctionKind, delta: Int, modelContext: ModelContext) {
        guard let run = runs.first(where: { $0.id == runID }) else { return }
        guard delta != 0 else { return }

        if let existing = run.malfunctions.first(where: { $0.kindRaw == kind.rawValue }) {
            existing.count = max(0, existing.count + delta)
        } else if delta > 0 {
            let m = RunMalfunction(run: run, kind: kind, count: delta)
            modelContext.insert(m)
            run.malfunctions.append(m)
        }

        run.malfunctionsCount = max(0, run.malfunctionsCount + delta)

        // ✅ Save deferred
        scheduleSave(modelContext)
        objectWillChange.send()
    }

    // MARK: Timer

    private func startTimer() {
        stopTimer()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.now = Date()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        now = Date()
    }
}

// MARK: - View

struct LiveSessionView: View {
    let preselectedFirearmID: UUID?

    init(preselectedFirearmID: UUID? = nil) {
        self.preselectedFirearmID = preselectedFirearmID
    }

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlements: Entitlements
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Firearm.createdAt, order: .reverse) private var firearms: [Firearm]
    @Query(sort: \AmmoProduct.createdAt, order: .reverse) private var ammoLibrary: [AmmoProduct]

    @StateObject private var vm = LiveSessionVM()

    @AppStorage("liveSession.rangeMode") private var rangeMode: Bool = true
    @State private var selectedMalfunctionKindByRun: [UUID: MalfunctionKind] = [:]

    @FocusState private var focusedField: FocusField?
    enum FocusField: Hashable {
        case runRounds(UUID)
        case runNotes(UUID)
        case sessionNotes
    }

    @State private var showAmmoPicker = false
    @State private var ammoPickerRunID: UUID? = nil

    @State private var showFirearmPicker = false
    @State private var pendingAddRun = false

    @State private var confirmEndSession = false
    @State private var confirmDeleteRunID: UUID? = nil

    @State private var roundsTextByRun: [UUID: String] = [:]
    @State private var isEditingRoundsForRun: UUID? = nil
    
    // Pro gating (Photos)
    @State private var showPaywall = false
    @State private var showPhotosProAlert = false

    // Photos flow
    @State private var showCamera = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var selectedPhotoForPreview: SessionPhoto? = nil

    @State private var pendingUIImage: UIImage? = nil
    @State private var pendingPickerImages: [UIImage] = []
    @State private var pendingPhotoTag: SessionPhotoTag = .target
    @State private var showPhotoTagSheet = false
    @State private var showNoActiveRunPhotoAlert = false
    
    private func gatePhotos() -> Bool {
        if entitlements.isPro { return true }
        haptic(.light)
        showPhotosProAlert = true
        return false
    }

    private var activeRunPhotos: [SessionPhoto] {
        guard let run = vm.activeRun else { return [] }
        // If FirearmRun has a relationship array like `photos`:
        return run.photos.sorted { $0.createdAt > $1.createdAt }
    }

    private func consumePreselectedStartIfNeeded() {
        guard let firearmID = preselectedFirearmID else { return }
        guard let firearm = firearms.first(where: { $0.id == firearmID }) else { return }

        if vm.state == .idle || vm.session == nil {
            vm.startSession(modelContext: modelContext)
        }

        if vm.state == .running {
            vm.endActiveRunIfNeeded(modelContext: modelContext)
            vm.startNewRun(modelContext: modelContext, firearm: firearm)
        }
    }

    //MARK: Ammo Helpers

    private func roundsText(for run: FirearmRun) -> String {
        if let t = roundsTextByRun[run.id] { return t }
        return String(run.rounds)
    }

    private func setRoundsText(_ text: String, for run: FirearmRun) {
        // Allow empty while typing
        roundsTextByRun[run.id] = text

        // Persist only when it parses
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let val = Int(trimmed) else { return }

        vm.updateRun(run.id, modelContext: modelContext) { r in
            r.rounds = max(0, val)
        }
    }

    private func commitRoundsText(for run: FirearmRun) {
        let trimmed = (roundsTextByRun[run.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let val = Int(trimmed) ?? run.rounds
        roundsTextByRun[run.id] = String(max(0, val))
        vm.updateRun(run.id, modelContext: modelContext) { r in
            r.rounds = max(0, val)
        }
    }

    // MARK: Photo helpers

    private func beginAddPhotoFlow(images: [UIImage]) {
        guard entitlements.isPro else {
            haptic(.light)
            showPhotosProAlert = true
            return
        }

        guard vm.activeRun != nil else {
            haptic(.light)
            showNoActiveRunPhotoAlert = true
            return
        }

        focusedField = nil
        pendingPickerImages = images
        pendingUIImage = images.first
        pendingPhotoTag = .target
        showPhotoTagSheet = true
    }

    private func persistPendingPhotosToActiveRun() {
        guard let run = vm.activeRun else { return }

        let images = pendingPickerImages
        pendingPickerImages = []
        pendingUIImage = nil
        showPhotoTagSheet = false

        guard !images.isEmpty else { return }

        for img in images {
            guard let jpeg = img.jpegData(compressionQuality: 0.82) else { continue }

            // ✅ make a small thumb to render fast
            let thumb = img.preparingThumbnail(of: CGSize(width: 160, height: 160))?
                .jpegData(compressionQuality: 0.7)

            let photo = SessionPhoto(run: run, imageData: jpeg, thumbnailData: thumb, tag: pendingPhotoTag)
            modelContext.insert(photo)
        }

        // ✅ Save deferred (never block UI)
        Task { @MainActor in
            try? modelContext.save()
        }

        haptic(.medium)
    }

    private func handlePickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        guard vm.activeRun != nil else {
            haptic(.light)
            showNoActiveRunPhotoAlert = true
            pickedItems = []
            return
        }

        focusedField = nil

        Task {
            var images: [UIImage] = []
            images.reserveCapacity(items.count)

            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }

            await MainActor.run {
                pickedItems = []
                if !images.isEmpty {
                    beginAddPhotoFlow(images: images)
                }
            }
        }
    }

    private func addCameraPhoto(_ image: UIImage) {
        beginAddPhotoFlow(images: [image])
    }

    private func deletePhoto(_ p: SessionPhoto) {
        modelContext.delete(p)
        // ✅ Save deferred
        Task { @MainActor in
            try? modelContext.save()
        }
        haptic(.light)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard
                activeCard

                if !rangeMode {
                    runsCard
                    notesCard
                    debugCard
                } else {
                    disclosureExtras
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 90)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Live Session")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { topMenu }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    // If we were editing a specific run's rounds, commit that one
                    if let rid = isEditingRoundsForRun,
                       let run = vm.runs.first(where: { $0.id == rid }) {
                        commitRoundsText(for: run)
                    } else if let run = vm.activeRun {
                        // Fallback
                        commitRoundsText(for: run)
                    }

                    isEditingRoundsForRun = nil
                    focusedField = nil
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }

        .alert("Stop session?", isPresented: $confirmEndSession) {
            Button("Stop Session", role: .destructive) { endSessionTapped() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will finalize the session and save all runs.")
        }

        .confirmationDialog("Delete run?", isPresented: Binding(
            get: { confirmDeleteRunID != nil },
            set: { if !$0 { confirmDeleteRunID = nil } }
        ), titleVisibility: .visible) {
            Button("Delete Run", role: .destructive) {
                if let id = confirmDeleteRunID {
                    vm.deleteRun(id, modelContext: modelContext)
                    selectedMalfunctionKindByRun[id] = nil
                }
                confirmDeleteRunID = nil
            }
            Button("Cancel", role: .cancel) { confirmDeleteRunID = nil }
        } message: {
            Text("This can’t be undone.")
        }

        .alert("Upgrade to Pro", isPresented: $showPhotosProAlert) {
            Button("Not now", role: .cancel) {}
            Button("See Pro") { showPaywall = true }
        } message: {
            Text("Adding photos to firearm runs is a Pro feature.")
        }

        .sheet(isPresented: $showPaywall) {
            PayWallView(
                title: "RoundCount Pro",
                subtitle: "Add photos to firearm runs (targets + malfunctions) with Pro."
            )
            .environmentObject(entitlements)
        }
        
        .sheet(isPresented: $showFirearmPicker) {
            NavigationStack {
                FirearmPickerSheet(
                    firearms: firearms,
                    onPick: { picked in
                        showFirearmPicker = false
                        if pendingAddRun {
                            pendingAddRun = false
                            vm.startNewRun(modelContext: modelContext, firearm: picked)
                            haptic(.medium)
                        }
                    },
                    onCancel: {
                        pendingAddRun = false
                        showFirearmPicker = false
                    }
                )
            }
        }

        .sheet(isPresented: $showAmmoPicker) {
            NavigationStack {
                AmmoPickerSheet(
                    ammo: ammoLibrary,
                    selectedID: ammoPickerRunID.flatMap { rid in
                        vm.runs.first(where: { $0.id == rid })?.ammo?.id
                    },
                    onPick: { picked in
                        guard let rid = ammoPickerRunID else { return }
                        vm.updateRun(rid, modelContext: modelContext) { r in
                            r.ammo = picked
                            r.defaultAmmo = picked
                        }
                        ammoPickerRunID = nil
                        showAmmoPicker = false
                        haptic(.light)
                    },
                    onClear: {
                        guard let rid = ammoPickerRunID else { return }
                        vm.updateRun(rid, modelContext: modelContext) { r in
                            r.ammo = nil
                        }
                        ammoPickerRunID = nil
                        showAmmoPicker = false
                        haptic(.light)
                    },
                    onCancel: {
                        ammoPickerRunID = nil
                        showAmmoPicker = false
                    }
                )
            }
        }

        .onAppear { consumePreselectedStartIfNeeded() }
        .onChange(of: firearms.count) { _, _ in consumePreselectedStartIfNeeded() }
        .onAppear { syncIdleTimer() }
        .onChange(of: vm.state) { _, _ in syncIdleTimer() }
        .onDisappear {
            Task { @MainActor in
                try? modelContext.save()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                Task { @MainActor in
                    try? modelContext.save()
                }
            }
        }
    }

    // MARK: - Menus / Bars

    private var topMenu: some View {
        Menu {
            Toggle(isOn: $rangeMode) {
                Label("Range Mode", systemImage: "scope")
            }

            Divider()

            if vm.state == .idle {
                Button("Start Session") { startSessionTapped() }
            }
            if vm.state == .running {
                Button("Add Run") { addRunTapped() }
                Button("Pause") { pauseTapped() }
                Button("End Session", role: .destructive) { confirmEndSession = true }
            }
            if vm.state == .paused {
                Button("Resume") { resumeTapped() }
                Button("End Session", role: .destructive) { confirmEndSession = true }
            }
            if vm.state == .ended {
                Button("New Session") { vm.resetSession() }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                switch vm.state {
                case .idle:
                    Button("Start Session") { startSessionTapped() }
                        .buttonStyle(ActionButtonStyle(prominent: true))

                case .running:
                    Button {
                        addRunTapped()
                    } label: {
                        VStack(spacing: 2) {
                            Text("Add Run")
                            Text("Track Firearm")
                                .font(.caption2)
                                .opacity(0.8)
                        }
                    }
                    .buttonStyle(ActionButtonStyle(prominent: true))

                    Button("Pause") { pauseTapped() }
                        .buttonStyle(ActionButtonStyle())

                    Button("End") { confirmEndSession = true }
                        .buttonStyle(ActionButtonStyle(role: .destructive))

                case .paused:
                    Button("Resume") { resumeTapped() }
                        .buttonStyle(ActionButtonStyle(prominent: true))

                    Button("End") { confirmEndSession = true }
                        .buttonStyle(ActionButtonStyle(role: .destructive))

                case .ended:
                    Button("New Session") {
                        vm.resetSession()
                        haptic(.light)
                    }
                    .buttonStyle(ActionButtonStyle(prominent: true))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        Card {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusText).font(.headline).foregroundStyle(statusColor)
                        Text("Session").font(.caption).foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatDuration(vm.sessionDuration))
                            .font(.title3).fontWeight(.semibold)
                            .monospacedDigit()
                        Text("Time").font(.caption).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    StatPill(title: "Rounds", value: "\(vm.totalRounds)")
                    StatPill(title: "Malfunctions", value: "\(vm.totalMalfunctions)")
                }

                if vm.state == .ended {
                    Text("Session saved.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("Photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    focusedField = nil
                    guard gatePhotos() else { return }
                    showCamera = true
                    haptic(.light)
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(ChipButtonStyle())

                PhotosPicker(selection: $pickedItems, maxSelectionCount: 10, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(ChipButtonStyle())
                .disabled(!entitlements.isPro)
                .opacity(entitlements.isPro ? 1.0 : 0.55)
                .onTapGesture {
                    // Helps explain *why* it's disabled
                    if !entitlements.isPro {
                        _ = gatePhotos()
                    }
                }
                .onChange(of: pickedItems) { _, newItems in
                    // Double safety: if picker somehow returns items, refuse
                    guard entitlements.isPro else {
                        pickedItems = []
                        _ = gatePhotos()
                        return
                    }
                    handlePickedPhotos(newItems)
                }
            }

            if vm.activeRun == nil {
                Text("Start a run to add photos. Photos attach to the active firearm run.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if activeRunPhotos.isEmpty {
                Text("Add target photos or malfunction evidence for this run.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(activeRunPhotos) { p in
                            PhotoThumb(photo: p)
                                .onTapGesture { selectedPhotoForPreview = p }
                                .contextMenu {
                                    Button(role: .destructive) { deletePhoto(p) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .alert("Select a run first", isPresented: $showNoActiveRunPhotoAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Photos must be attached to a specific firearm run. Start or select a run first.")
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                if let image { addCameraPhoto(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoTagSheet) {
            NavigationStack {
                VStack(spacing: 14) {
                    Text("Tag these photo(s)")
                        .font(.headline)

                    Picker("Tag", selection: $pendingPhotoTag) {
                        ForEach(SessionPhotoTag.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let img = pendingUIImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.quaternary, lineWidth: 1)
                            )
                    }

                    HStack(spacing: 12) {
                        Button("Cancel", role: .cancel) {
                            pendingPickerImages = []
                            pendingUIImage = nil
                            showPhotoTagSheet = false
                        }

                        Spacer()

                        Button("Save") { persistPendingPhotosToActiveRun() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .navigationTitle("Photo Tag")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: $selectedPhotoForPreview) { (p: SessionPhoto) in
            PhotoPreview(photo: p)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            deletePhoto(p)
                            selectedPhotoForPreview = nil
                        } label: { Image(systemName: "trash") }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { selectedPhotoForPreview = nil }
                    }
                }
        }
    }

    private var activeCard: some View {
        Card(neon: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active").font(.headline)
                    Spacer()
                    if vm.state == .running, vm.activeRun != nil {
                        Text("LIVE")
                            .font(.caption).fontWeight(.bold)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.green.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                photosSection

                if let run = vm.activeRun {
                    firearmPickerRow(runID: run.id, selectedFirearmID: run.firearm.id)
                    ammoPickerRow(run: run)

                    VStack(alignment: .leading, spacing: 12) {
                        totalRoundsEntry(run: run)
                        magsLoggedControl(run: run)
                        roundsCorrectionsControl(run: run)
                        malfunctionsControl(run: run)
                    }
                    .onChange(of: run.rounds) { _, newValue in
                        // Keep the total TextField synced with button taps + mag taps
                        if isEditingRoundsForRun != run.id {
                            roundsTextByRun[run.id] = String(newValue)
                        }
                    }

                    HStack {
                        Text("Time on firearm")
                        Spacer()
                        Text(formatDuration(TimeInterval(run.durationSeconds)))
                            .monospacedDigit().fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    RunNotesEditor(
                        text: run.notes ?? "",
                        runID: run.id,
                        focusedField: $focusedField
                    ) { updated in
                        vm.updateRun(run.id, modelContext: modelContext) { r in
                            r.notes = updated.isEmpty ? nil : updated
                        }
                    }

                    HStack {
                        Button {
                            focusedField = nil
                            vm.endActiveRunIfNeeded(modelContext: modelContext)
                            haptic(.light)
                        } label: {
                            Label("Switch", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button(role: .destructive) {
                            focusedField = nil
                            confirmDeleteRunID = run.id
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ContentUnavailableView(
                        vm.state == .idle ? "Ready to start" :
                            (vm.state == .paused ? "Paused" :
                                (vm.state == .ended ? "Session ended" : "No active run")),
                        systemImage: vm.state == .idle ? "scope" :
                            (vm.state == .paused ? "pause.circle" :
                                (vm.state == .ended ? "checkmark.circle" : "scope")),
                        description: Text(vm.state == .running
                                          ? (firearms.isEmpty ? "Add a firearm first." : "Tap “Add Run” to start tracking.")
                                          : (vm.state == .idle ? "Start a session when you’re on the line."
                                             : (vm.state == .paused ? "Resume when you’re ready."
                                                : "Start a new session when you’re ready.")))
                    )
                }
            }
        }
    }

    private var runsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Runs").font(.headline)

                if vm.runs.isEmpty {
                    Text("No runs yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.runs) { run in
                        runRow(run)
                        Divider().opacity(0.4)
                    }
                }
            }
        }
    }

    private var notesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Session Notes").font(.headline)

                TextEditor(text: Binding(
                    get: { vm.sessionNotes },
                    set: { vm.updateSessionNotes(modelContext: modelContext, notes: $0) }
                ))
                .focused($focusedField, equals: .sessionNotes)
                .frame(minHeight: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
            }
        }
    }

    private var debugCard: some View {
        Card {
            Text("Session: \(vm.session?.id.uuidString.prefix(6) ?? "none") • Runs: \(vm.runs.count) • Active: \(vm.activeRunID?.uuidString.prefix(6) ?? "none")")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var disclosureExtras: some View {
        Card {
            DisclosureGroup("More") {
                VStack(spacing: 12) {
                    runsCard
                    notesCard
                    debugCard
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Rows / Controls

    private func runRow(_ run: FirearmRun) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(run.firearm.displayName).fontWeight(.semibold)
                Spacer()

                if run.id == vm.activeRunID {
                    Text("LIVE")
                        .font(.caption).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.green.opacity(0.2))
                        .clipShape(Capsule())
                } else if vm.state == .running {
                    Button("Continue") {
                        focusedField = nil
                        vm.continueRun(from: run.id, modelContext: modelContext)
                        haptic(.light)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }

            HStack {
                Text("Rounds: \(run.rounds)")
                Text("•")
                Text("MF: \(run.malfunctionsCount)")
                Text("•")
                Text("Ammo: \(run.ammoDisplayLabel)")
                Text("•")
                Text("Time: \(formatDuration(TimeInterval(run.durationSeconds)))")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let notes = run.notes, !notes.isEmpty {
                Text(notes).font(.subheadline)
            }
        }
    }

    private func roundsQuickControl(run: FirearmRun) -> some View {
        let mags = run.firearm.magazines.sorted(by: { $0.capacity < $1.capacity })
        let selected = run.selectedMagazine ?? mags.first
        let cap = max(1, selected?.capacity ?? 17)

        // Derived “mags totaled”
        let fullMags = run.rounds / cap
        let remainder = run.rounds % cap

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Right side: mags tally (fast feedback)
                HStack(spacing: 8) {
                    Text("Mags:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(remainder == 0
                         ? "\(fullMags)"
                         : "\(fullMags) + \(remainder)")
                        .monospacedDigit()
                        .font(.subheadline.weight(.semibold))

                    Text("@\(cap)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Primary: total entry
            HStack(spacing: 10) {
                Text("Total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                TextField("0", text: Binding(
                    get: { roundsText(for: run) },
                    set: { setRoundsText($0, for: run) }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 90)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
            }

            // Primary quick deltas (includes understack corrections)
            HStack(spacing: 10) {
                Button("−1") { bumpRounds(runID: run.id, delta: -1) }
                Button("−2") { bumpRounds(runID: run.id, delta: -2) }
                Button("−5") { bumpRounds(runID: run.id, delta: -5) }

                Spacer()

                Button("+1") { bumpRounds(runID: run.id, delta: 1) }
                Button("+2") { bumpRounds(runID: run.id, delta: 2) }
                Button("+5") { bumpRounds(runID: run.id, delta: 5) }
            }
            .buttonStyle(.bordered)

            // Mag picker + mag-based accelerators (secondary)
            HStack(spacing: 10) {
                Menu {
                    if mags.isEmpty {
                        Text("No mags saved for this firearm").foregroundStyle(.secondary)
                    } else {
                        ForEach(mags) { m in
                            Button(m.displayName) {
                                vm.updateRun(run.id, modelContext: modelContext) { r in
                                    r.selectedMagazine = m
                                }
                                haptic(.light)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magazine.fill")
                            .font(.subheadline)

                        Text(selected?.displayName ?? "\(cap) / mag")
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .opacity(0.85)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .menuStyle(.button)

                Spacer()

                Button("−1 Mag") { bumpRounds(runID: run.id, delta: -cap) }
                    .buttonStyle(.bordered)

                Button("+1 Mag") { bumpRounds(runID: run.id, delta: cap) }
                    .buttonStyle(.bordered)

                Menu {
                    Button("+10") { bumpRounds(runID: run.id, delta: 10) }
                    Button("+15") { bumpRounds(runID: run.id, delta: 15) }
                    Button("+20") { bumpRounds(runID: run.id, delta: 20) }
                    Divider()
                    Button("+25") { bumpRounds(runID: run.id, delta: 25) }
                    Button("+50") { bumpRounds(runID: run.id, delta: 50) }
                    Divider()
                    Button("Reset", role: .destructive) {
                        vm.updateRun(run.id, modelContext: modelContext) { r in r.rounds = 0 }
                        roundsTextByRun[run.id] = "0"
                        haptic(.light)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.button)
            }
        }
    }

    private func malfunctionsControl(run: FirearmRun) -> some View {
        let kind = selectedKind(for: run.id)

        let breakdownPairs = run.malfunctions
            .filter { $0.count > 0 }
            .sorted { $0.kindRaw < $1.kindRaw }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Malfunctions").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(run.malfunctionsCount)").monospacedDigit().fontWeight(.semibold)
            }

            HStack(spacing: 10) {
                Menu {
                    ForEach(MalfunctionKind.allCases) { k in
                        Button(k.rawValue) {
                            selectedMalfunctionKindByRun[run.id] = k
                            haptic(.light)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.subheadline)

                        Text(kind.shortLabel)
                            .font(.subheadline)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .opacity(0.85)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .menuStyle(.button)

                Spacer()

                Button("−1") { bumpMalfunction(runID: run.id, kind: kind, delta: -1) }.buttonStyle(.bordered)
                Button("+1") { bumpMalfunction(runID: run.id, kind: kind, delta: 1) }.buttonStyle(.bordered)
                Button("+5") { bumpMalfunction(runID: run.id, kind: kind, delta: 5) }.buttonStyle(.bordered)
            }

            if !rangeMode, !breakdownPairs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(breakdownPairs) { m in
                            let k = MalfunctionKind(rawValue: m.kindRaw) ?? .other
                            Text("\(k.shortLabel): \(m.count)")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.secondary.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func firearmPickerRow(runID: UUID, selectedFirearmID: UUID) -> some View {
        HStack(spacing: 12) {
            Text("Firearm")
            Spacer(minLength: 8)

            Menu {
                ForEach(firearms) { f in
                    Button {
                        focusedField = nil
                        vm.updateRun(runID, modelContext: modelContext) { r in
                            r.firearm = f
                            r.selectedMagazine = f.magazines
                                .sorted(by: { $0.capacity < $1.capacity })
                                .first
                        }
                        haptic(.light)
                    } label: {
                        Text(f.displayName)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(firearms.first(where: { $0.id == selectedFirearmID })?.displayName ?? "Select firearm")
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .menuStyle(.button)
        }
    }

    private func ammoPickerRow(run: FirearmRun) -> some View {
        HStack(spacing: 12) {
            Text("Ammo")
            Spacer(minLength: 8)

            Button {
                focusedField = nil
                ammoPickerRunID = run.id
                showAmmoPicker = true
                haptic(.light)
            } label: {
                HStack(spacing: 8) {
                    Text(run.ammo == nil ? "None selected" : run.ammoDisplayLabel)
                        .foregroundStyle(run.ammo == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if run.ammo == nil {
                        Text("Optional")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.10))
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Actions

    private func startSessionTapped() {
        focusedField = nil

        // ✅ Ensure the gesture handler returns immediately (prevents "System gesture gate timed out")
        Task { @MainActor in
            vm.startSession(modelContext: modelContext)
            haptic(.medium)
        }
    }

    private func addRunTapped() {
        focusedField = nil
        guard !firearms.isEmpty else { return }

        if firearms.count == 1, let only = firearms.first {
            vm.startNewRun(modelContext: modelContext, firearm: only)
            haptic(.medium)
            return
        }

        pendingAddRun = true
        showFirearmPicker = true
    }

    private func pauseTapped() {
        focusedField = nil
        vm.pauseSession(modelContext: modelContext)
        haptic(.light)
    }

    private func resumeTapped() {
        focusedField = nil
        vm.resumeSession()
        haptic(.light)
    }

    private func endSessionTapped() {
        focusedField = nil
        vm.endSession(modelContext: modelContext)
        haptic(.medium)
    }

    private func bumpRounds(runID: UUID, delta: Int) {
        vm.updateRun(runID, modelContext: modelContext) { r in
            r.rounds = max(0, r.rounds + delta)
        }

        if let r = vm.runs.first(where: { $0.id == runID }) {
            roundsTextByRun[runID] = String(r.rounds)
        }

        haptic(.light)
    }

    private func totalRoundsEntry(run: FirearmRun) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Total Rounds")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TextField(
                    "0",
                    text: Binding(
                        get: {
                            roundsTextByRun[run.id] ?? String(run.rounds)
                        },
                        set: { newValue in
                            // Allow empty while typing
                            roundsTextByRun[run.id] = newValue
                            isEditingRoundsForRun = run.id

                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard let raw = Int(trimmed) else { return }
                            let value = max(0, raw)

                            vm.updateRun(run.id, modelContext: modelContext) { r in
                                r.rounds = max(0, value)
                            }
                        }
                    )
                )
                .keyboardType(.numberPad)
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .runRounds(run.id))
                .onTapGesture {
                    isEditingRoundsForRun = run.id
                    focusedField = .runRounds(run.id)
                }
                .onChange(of: focusedField) { _, newValue in
                    // When leaving this rounds field, commit
                    if isEditingRoundsForRun == run.id, newValue != .runRounds(run.id) {
                        commitRoundsText(for: run)
                        isEditingRoundsForRun = nil
                    }
                }

                // Optional clear/reset shortcut
                Button {
                    vm.updateRun(run.id, modelContext: modelContext) { r in r.rounds = 0 }
                    roundsTextByRun[run.id] = "0"
                    isEditingRoundsForRun = nil
                    haptic(.light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func magsLoggedControl(run: FirearmRun) -> some View {
        let mags = sortedMags(for: run.firearm)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Mags Logged")
                .font(.caption)
                .foregroundStyle(.secondary)

            if mags.isEmpty {
                Text("Add magazine types to this firearm to enable one-tap mag logging.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(mags) { mag in
                        Button {
                            bumpRounds(runID: run.id, delta: mag.capacity)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "magazine.fill")
                                            .foregroundStyle(.secondary)

                                        Text(mag.displayName) // “OEM 17 round”, “Atlas 140mm 21”
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }

                                    Text("\(mag.capacity) rounds")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("+\(mag.capacity)")
                                    .font(.headline.weight(.semibold))
                                    .monospacedDigit()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.secondary.opacity(0.10))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.quaternary, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contextMenu {
                            Button(role: .destructive) {
                                bumpRounds(runID: run.id, delta: -mag.capacity)
                            } label: {
                                Label("Remove \(mag.capacity) rounds", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            }
        }
    }

    private func roundsCorrectionsControl(run: FirearmRun) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adjust")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("−1") { bumpRounds(runID: run.id, delta: -1) }
                Button("−2") { bumpRounds(runID: run.id, delta: -2) }
                Button("−5") { bumpRounds(runID: run.id, delta: -5) }

                Spacer()

                Button("+1") { bumpRounds(runID: run.id, delta: 1) }
                Button("+2") { bumpRounds(runID: run.id, delta: 2) }
                Button("+5") { bumpRounds(runID: run.id, delta: 5) }
            }
            .buttonStyle(.bordered)
        }
    }

    private func sortedMags(for firearm: Firearm) -> [FirearmMagazine] {
        firearm.magazines.sorted {
            if $0.capacity != $1.capacity { return $0.capacity < $1.capacity }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func selectedKind(for runID: UUID) -> MalfunctionKind {
        selectedMalfunctionKindByRun[runID] ?? .failureToFeed
    }

    private func bumpMalfunction(runID: UUID, kind: MalfunctionKind, delta: Int) {
        vm.bumpMalfunction(runID: runID, kind: kind, delta: delta, modelContext: modelContext)
        haptic(.light)
    }

    private func quickPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }

    private func syncIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = (vm.state == .running || vm.state == .paused)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private var statusText: String {
        switch vm.state {
        case .idle: return "Ready"
        case .running: return "Running"
        case .paused: return "Paused"
        case .ended: return "Ended"
        }
    }

    private var statusColor: Color {
        switch vm.state {
        case .idle: return .secondary
        case .running: return .green
        case .paused: return .orange
        case .ended: return .secondary
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
}

// MARK: - Small UI Primitives

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.secondary.opacity(configuration.isPressed ? 0.18 : 0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension View {
    @ViewBuilder func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

private struct Card<Content: View>: View {
    private let content: Content
    private let neon: Bool

    init(neon: Bool = false, @ViewBuilder _ content: () -> Content) {
        self.content = content()
        self.neon = neon
    }

    var body: some View {
        VStack { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.clear)
            .if(neon) { $0.neonCard(cornerRadius: 16, intensity: 1.0) }
            .if(!neon) { view in
                view
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
            }
    }
}

private struct StatPill: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ActionButtonStyle: ButtonStyle {
    var role: ButtonRole? = nil
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(background(configuration))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func background(_ configuration: Configuration) -> some View {
        Group {
            if role == .destructive {
                Color.red.opacity(configuration.isPressed ? 0.85 : 1.0)
            } else if prominent {
                Brand.accent.opacity(configuration.isPressed ? 0.85 : 1.0)
            } else {
                Color.secondary.opacity(configuration.isPressed ? 0.15 : 0.20)
            }
        }
    }

    private var borderColor: Color {
        if role == .destructive { return .red.opacity(0.9) }
        if prominent { return Brand.accent.opacity(0.9) }
        return .secondary.opacity(0.25)
    }
}

// MARK: - Notes Editor

private struct RunNotesEditor: View {
    @State private var text: String
    let runID: UUID
    @FocusState.Binding var focusedField: LiveSessionView.FocusField?
    private let onCommit: (String) -> Void

    init(
        text: String,
        runID: UUID,
        focusedField: FocusState<LiveSessionView.FocusField?>.Binding,
        onCommit: @escaping (String) -> Void
    ) {
        _text = State(initialValue: text)
        self.runID = runID
        self._focusedField = focusedField
        self.onCommit = onCommit
    }

    var body: some View {
        TextField("Notes (optional)", text: $text)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .focused($focusedField, equals: .runNotes(runID))
            .onSubmit { focusedField = nil }
            .onChange(of: text) { _, newValue in
                onCommit(newValue)
            }
    }
}

// MARK: - Firearm Picker Sheet

private struct FirearmPickerSheet: View {
    let firearms: [Firearm]
    let onPick: (Firearm) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var filtered: [Firearm] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return firearms }
        return firearms.filter { $0.displayName.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            ForEach(filtered) { f in
                Button {
                    onPick(f)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.displayName).fontWeight(.semibold)
                        Text(f.caliber).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Select Firearm")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel(); dismiss() }
            }
        }
    }
}

private struct AmmoPickerSheet: View {
    let ammo: [AmmoProduct]
    let selectedID: UUID?
    let onPick: (AmmoProduct) -> Void
    let onClear: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var filtered: [AmmoProduct] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return ammo }
        return ammo.filter { a in
            a.displayName.localizedCaseInsensitiveContains(q)
            || a.brand.localizedCaseInsensitiveContains(q)
            || a.caliber.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    onClear()
                    dismiss()
                } label: {
                    Label("Clear Ammo", systemImage: "xmark.circle")
                }
            }

            Section("Ammo") {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "tray.fill",
                        description: Text("Try another search.")
                    )
                } else {
                    ForEach(filtered) { a in
                        Button {
                            onPick(a)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(shortTitle(a))
                                        .font(.headline)
                                        .lineLimit(1)

                                    Text(a.displayName)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if selectedID == a.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Select Ammo")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel(); dismiss() }
            }
        }
    }

    private func shortTitle(_ a: AmmoProduct) -> String {
        let line = (a.productLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        return line.isEmpty ? a.brand : "\(a.brand) \(line)"
    }
}

// MARK: - Photos UI (Live Session)

private struct PhotoThumb: View {
    let photo: SessionPhoto

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let data = photo.thumbnailData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else if let img = UIImage(data: photo.imageData) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack {
                        Rectangle().fill(.secondary.opacity(0.15))
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )

            Image(systemName: photo.tag.systemImage)
                .font(.caption2.weight(.semibold))
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .padding(6)
        }
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

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onComplete: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onComplete(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
            onComplete(image)
        }
    }
}
