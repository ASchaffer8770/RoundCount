import Combine
import SwiftUI

// MARK: - Preference Key

/// Collects global-coordinate frames from annotated views across the entire view tree.
struct CoachMarkFrameKey: PreferenceKey {
    typealias Value = [String: CGRect]
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Model

struct CoachMarkStep {
    let anchorID: String
    let title: String
    let message: String
}

enum CoachMarkSequenceID: String {
    case dashboard
    case liveSession
    case ammo
    case firearms
}

// MARK: - Manager

@MainActor
final class CoachMarkManager: ObservableObject {

    @Published private(set) var activeSequenceID: CoachMarkSequenceID?
    @Published private(set) var stepIndex: Int = 0
    @Published var frames: [String: CGRect] = [:]

    @AppStorage("cm.dashboard.v1")   private var dashboardDone   = false
    @AppStorage("cm.liveSession.v1") private var liveSessionDone = false
    @AppStorage("cm.ammo.v1")        private var ammoDone        = false
    @AppStorage("cm.firearms.v1")    private var firearmsDone    = false

    var currentStep: CoachMarkStep? {
        guard let id = activeSequenceID else { return nil }
        let s = steps(for: id)
        guard stepIndex < s.count else { return nil }
        return s[stepIndex]
    }

    func startIfNeeded(_ id: CoachMarkSequenceID) {
        guard !isDone(id), activeSequenceID == nil else { return }
        activeSequenceID = id
        stepIndex = 0
    }

    func advance() {
        guard let id = activeSequenceID else { return }
        if stepIndex + 1 < steps(for: id).count {
            stepIndex += 1
        } else {
            finish()
        }
    }

    func skip() { finish() }

    func resetAll() {
        dashboardDone   = false
        liveSessionDone = false
        ammoDone        = false
        firearmsDone    = false
        activeSequenceID = nil
        stepIndex = 0
    }

    private func finish() {
        guard let id = activeSequenceID else { return }
        markDone(id)
        activeSequenceID = nil
    }

    private func isDone(_ id: CoachMarkSequenceID) -> Bool {
        switch id {
        case .dashboard:   return dashboardDone
        case .liveSession: return liveSessionDone
        case .ammo:        return ammoDone
        case .firearms:    return firearmsDone
        }
    }

    private func markDone(_ id: CoachMarkSequenceID) {
        switch id {
        case .dashboard:   dashboardDone   = true
        case .liveSession: liveSessionDone = true
        case .ammo:        ammoDone        = true
        case .firearms:    firearmsDone    = true
        }
    }

    func steps(for id: CoachMarkSequenceID) -> [CoachMarkStep] {
        switch id {
        case .dashboard:
            return [
                .init(
                    anchorID: "dashboard.quickActions",
                    title: "Your Home Base",
                    message: "Stats and history fill in automatically as you log sessions. Start by adding a firearm, then head to the Sessions tab to record your first range visit."
                ),
            ]
        case .liveSession:
            return [
                .init(
                    anchorID: "liveSession.start",
                    title: "Start a Session",
                    message: "Tap here when you arrive at the range. RoundCount tracks your time and everything you shoot from the moment you start."
                ),
                .init(
                    anchorID: "liveSession.addRun",
                    title: "Add a Run",
                    message: "A run is one gun, one stint of shooting. Add a run for each firearm you use during your visit — as many as you want."
                ),
                .init(
                    anchorID: "liveSession.end",
                    title: "End When You're Done",
                    message: "Tap here to wrap up. Your round counts, malfunctions, and total time are all saved automatically."
                ),
            ]
        case .ammo:
            return [
                .init(
                    anchorID: "ammo.add",
                    title: "Build Your Ammo Library",
                    message: "Add the ammo you shoot. Select it on a run to track malfunction rates and consumption per load. You can also scan any UPC barcode to auto-fill the details."
                ),
            ]
        case .firearms:
            return [
                .init(
                    anchorID: "firearms.add",
                    title: "Add Your Firearms",
                    message: "Everything in RoundCount is tied to a firearm. Add yours here to start tracking sessions, round counts, and reliability over time."
                ),
            ]
        }
    }
}
