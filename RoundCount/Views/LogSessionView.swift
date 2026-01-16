import SwiftUI
import SwiftData

struct LogSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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


    // UI state
    @State private var showAddFirearm = false
    @State private var showToast = false
    @State private var toastText = "Session logged"

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
                    } else {
                        EmptyView()
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
        }
    }

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
            notes: trimmed.isEmpty ? nil : trimmed
        )


        modelContext.insert(session)
        firearm.totalRounds += rounds

        // Reset for fast follow-up logs
        roundsText = ""
        notes = ""
        sessionDate = Date()

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
}
