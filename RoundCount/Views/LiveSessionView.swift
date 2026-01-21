//
//  LiveSessionView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/19/26.
//

import SwiftUI
import SwiftData
import Combine
import UIKit
import PhotosUI
import Foundation


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

    // MARK: Lifecycle

    func startSession(modelContext: ModelContext) {
        guard state == .idle else { return }

        let s = SessionV2(startedAt: Date(), endedAt: nil, notes: nil)
        modelContext.insert(s)
        try? modelContext.save()

        session = s
        startedAt = s.startedAt
        elapsedCarry = 0
        resumeAnchor = startedAt
        endedAt = s.endedAt
        sessionNotes = s.notes ?? ""

        runs = s.runs.sorted(by: { $0.startedAt < $1.startedAt })
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
        try? modelContext.save()

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
        try? modelContext.save()

        runs = s.runs.sorted(by: { $0.startedAt < $1.startedAt })
        activeRunID = run.id
        objectWillChange.send()
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

        // carry forward ammo selection (nice UX)
        newRun.ammo = prior.ammo
        newRun.defaultAmmo = prior.defaultAmmo

        modelContext.insert(newRun)
        s.runs.append(newRun)
        try? modelContext.save()

        runs = s.runs.sorted(by: { $0.startedAt < $1.startedAt })
        activeRunID = newRun.id
        objectWillChange.send()
    }

    func endActiveRunIfNeeded(modelContext: ModelContext) {
        guard let idx = activeRunIndex else { return }
        let run = runs[idx]
        if run.endedAt == nil {
            run.endedAt = Date()
            try? modelContext.save()
        }
        activeRunID = nil
        objectWillChange.send()
    }

    func updateRun(_ runID: UUID, modelContext: ModelContext, mutate: (FirearmRun) -> Void) {
        guard let run = runs.first(where: { $0.id == runID }) else { return }
        mutate(run)
        try? modelContext.save()
        objectWillChange.send()
    }

    func deleteRun(_ runID: UUID, modelContext: ModelContext) {
        if activeRunID == runID { activeRunID = nil }
        guard let run = runs.first(where: { $0.id == runID }) else { return }

        if let s = session { s.runs.removeAll(where: { $0.id == runID }) }
        modelContext.delete(run)
        try? modelContext.save()

        if let s = session {
            runs = s.runs.sorted(by: { $0.startedAt < $1.startedAt })
        } else {
            runs.removeAll(where: { $0.id == runID })
        }
        objectWillChange.send()
    }

    func updateSessionNotes(modelContext: ModelContext, notes: String) {
        sessionNotes = notes
        session?.notes = notes
        try? modelContext.save()
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

        // keep summary in sync
        run.malfunctionsCount = max(0, run.malfunctionsCount + delta)

        try? modelContext.save()
        objectWillChange.send()
    }

    // MARK: Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.now = Date()
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
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlements: Entitlements
    @EnvironmentObject private var tabRouter: AppTabRouter
    @Query(sort: \Firearm.createdAt, order: .reverse) private var firearms: [Firearm]
    @Query(sort: \AmmoProduct.createdAt, order: .reverse) private var ammoLibrary: [AmmoProduct]

    @State private var showAmmoPicker = false
    @State private var ammoPickerRunID: UUID? = nil

    @StateObject private var vm = LiveSessionVM()

    @AppStorage("liveSession.rangeMode") private var rangeMode: Bool = true

    @State private var selectedMalfunctionKindByRun: [UUID: MalfunctionKind] = [:]

    @FocusState private var focusedField: FocusField?
    enum FocusField: Hashable {
        case runNotes(UUID)
        case sessionNotes
    }

    private func consumePendingLiveStartIfNeeded() {
        guard let firearmID = tabRouter.pendingLiveFirearmID else { return }
        guard let firearm = firearms.first(where: { $0.id == firearmID }) else {
            tabRouter.clearPendingLiveRequest()
            return
        }

        if vm.state == .idle || vm.session == nil {
            vm.startSession(modelContext: modelContext)
        }

        if vm.state == .running {
            vm.endActiveRunIfNeeded(modelContext: modelContext)
            vm.startNewRun(modelContext: modelContext, firearm: firearm)
        }

        tabRouter.clearPendingLiveRequest()
    }

    @State private var showFirearmPicker = false
    @State private var pendingAddRun = false

    @State private var confirmEndSession = false
    @State private var confirmDeleteRunID: UUID? = nil
    
    // MARK: Photos (V1)
    @State private var showCamera = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var selectedPhotoForPreview: SessionPhoto? = nil

    @Query(sort: \SessionPhoto.createdAt, order: .reverse)
    private var allSessionPhotos: [SessionPhoto]

    private var currentSessionPhotos: [SessionPhoto] {
        guard let sid = vm.session?.id else { return [] }
        return allSessionPhotos.filter { $0.session?.id == sid }
    }

    private func addPhoto(_ image: UIImage) {
        guard let s = vm.session else { return }
        guard let _ = vm.activeRun else {
            // User feedback if they try to add without a run
            print("Attempted to add photo without an active run")
            haptic(.light)
            return
        }

        do {
            let path = try ImageStore.saveJPEG(image, quality: 0.82)
            let photo = SessionPhoto(filePath: path, session: s, run: vm.activeRun)
            modelContext.insert(photo)
            try? modelContext.save()
            haptic(.medium)
        } catch {
            haptic(.light)
        }
    }

    private func deletePhoto(_ p: SessionPhoto) {
        ImageStore.delete(path: p.filePath)
        modelContext.delete(p)
        try? modelContext.save()
        haptic(.light)
    }

    private func handlePickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        guard vm.activeRun != nil else {
            print("PhotosPicker: no active run; ignoring selection")
            haptic(.light)
            return
        }
        focusedField = nil

        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { addPhoto(image) }
                }
            }
            await MainActor.run { pickedItems = [] }
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
                // 👇 PhotosPicker ignores some button styles unless you apply it like this
                .buttonStyle(ChipButtonStyle())
                .onChange(of: pickedItems) { _, newItems in
                    handlePickedPhotos(newItems)
                }
            }

            if vm.activeRun == nil {
                Text("Start a run to add and save photos to this session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if currentSessionPhotos.isEmpty {
                Text("Add target photos, malfunctions, or notes from the line.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(currentSessionPhotos) { p in
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
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                if let image { addPhoto(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedPhotoForPreview) { (p: SessionPhoto) in
            NavigationStack {
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
    }


    var body: some View {
        NavigationStack {
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
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }

            // ✅ Fix "weird dialog": use alert for end-session confirmation
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

            .sheet(isPresented: $showFirearmPicker) {
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
            .sheet(isPresented: $showAmmoPicker) {
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

            .onAppear { consumePendingLiveStartIfNeeded() }
            .onChange(of: tabRouter.pendingLiveFirearmID) { _, _ in consumePendingLiveStartIfNeeded() }
            .onAppear { syncIdleTimer() }
            .onChange(of: vm.state) { _, _ in syncIdleTimer() }
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
                    Button("Start Session") {
                        startSessionTapped()
                    }
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

                    Button("Pause") {
                        pauseTapped()
                    }
                    .buttonStyle(ActionButtonStyle())

                    Button("End") {
                        confirmEndSession = true
                    }
                    .buttonStyle(ActionButtonStyle(role: .destructive))

                case .paused:
                    Button("Resume") {
                        resumeTapped()
                    }
                    .buttonStyle(ActionButtonStyle(prominent: true))

                    Button("End") {
                        confirmEndSession = true
                    }
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

    // ✅ Neon Active card
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
                        roundsQuickControl(run: run)
                        malfunctionsControl(run: run)
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
        let cap = selected?.capacity ?? 17

        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: rangeMode ? 3 : 4)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Rounds").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(run.rounds)").monospacedDigit().fontWeight(.semibold)
            }

            LazyVGrid(columns: cols, spacing: 8) {
                quickPill("+5")  { bumpRounds(runID: run.id, delta: 5) }
                quickPill("+10") { bumpRounds(runID: run.id, delta: 10) }
                quickPill("+15") { bumpRounds(runID: run.id, delta: 15) }
                quickPill("+20") { bumpRounds(runID: run.id, delta: 20) }
                quickPill("+25") { bumpRounds(runID: run.id, delta: 25) }
                quickPill("+50") { bumpRounds(runID: run.id, delta: 50) }

                if !rangeMode {
                    quickPill("+100") { bumpRounds(runID: run.id, delta: 100) }
                    quickPill("Reset") {
                        vm.updateRun(run.id, modelContext: modelContext) { r in r.rounds = 0 }
                        haptic(.light)
                    }
                }
            }

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

                Button("+1 Mag") { bumpRounds(runID: run.id, delta: cap) }.buttonStyle(.bordered)
                Button("+2") { bumpRounds(runID: run.id, delta: cap * 2) }.buttonStyle(.bordered)
                Button("−1") { bumpRounds(runID: run.id, delta: -cap) }.buttonStyle(.bordered)
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
                    Text(
                        firearms.first(where: { $0.id == selectedFirearmID })?.displayName
                        ?? "Select firearm"
                    )
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
                        .strokeBorder(run.ammo == nil ? Color.secondary.opacity(0.35) : Color.secondary.opacity(0.20), lineWidth: 1)
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
        vm.startSession(modelContext: modelContext)
        haptic(.medium)
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
        haptic(.light)
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
        if role == .destructive {
            return .red.opacity(0.9)
        }
        if prominent {
            return Brand.accent.opacity(0.9)
        }
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
            .onChange(of: text) { onCommit($0) }
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
        NavigationStack {
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
        NavigationStack {
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
        Group {
            if let img = ImageStore.loadImage(path: photo.filePath) {
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
        .frame(width: 76, height: 76)
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
            if let img = ImageStore.loadImage(path: photo.filePath) {
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


#Preview {
    LiveSessionView().environmentObject(Entitlements())
}
