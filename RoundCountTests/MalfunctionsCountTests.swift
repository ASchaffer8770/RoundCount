import Testing
import SwiftData
@testable import RoundCount

// These tests directly verify the fix for the malfunctionsCount drift bug.
// Before the fix, malfunctionsCount was a stored Int that could get out of sync
// with the malfunctions relationship. Now it's computed — these tests prove it.

@Suite("FirearmRun.malfunctionsCount")
@MainActor
struct MalfunctionsCountTests {

    let container: ModelContainer
    let ctx: ModelContext

    init() throws {
        container = try makeTestContainer()
        ctx = ModelContext(container)
    }

    // MARK: - Baseline

    @Test func noMalfunctions_isZero() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)

        #expect(run.malfunctionsCount == 0)
    }

    // MARK: - Single kind

    @Test func singleKind_reflectsCount() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)

        makeMalfunction(in: ctx, run: run, kind: .failureToFeed, count: 3)

        #expect(run.malfunctionsCount == 3)
    }

    // MARK: - Multiple kinds

    @Test func multipleKinds_sumsAll() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)

        makeMalfunction(in: ctx, run: run, kind: .failureToFeed,    count: 2)
        makeMalfunction(in: ctx, run: run, kind: .stovepipe,        count: 3)
        makeMalfunction(in: ctx, run: run, kind: .doubleFeed,       count: 1)

        #expect(run.malfunctionsCount == 6)
    }

    @Test func allKinds_sumCorrectly() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)

        for (i, kind) in MalfunctionKind.allCases.enumerated() {
            makeMalfunction(in: ctx, run: run, kind: kind, count: i + 1)
        }

        let expected = (1...MalfunctionKind.allCases.count).reduce(0, +)
        #expect(run.malfunctionsCount == expected)
    }

    // MARK: - Mutation tracking (the core drift fix)

    @Test func countUpdatesWhenRunMalfunctionCountChanges() {
        // The old stored Int would NOT update when RunMalfunction.count was mutated.
        // The computed property always re-derives, so this must stay in sync.
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)
        let malf = makeMalfunction(in: ctx, run: run, kind: .failureToFeed, count: 1)

        #expect(run.malfunctionsCount == 1)

        malf.count = 5
        #expect(run.malfunctionsCount == 5)

        malf.count = 0
        #expect(run.malfunctionsCount == 0)
    }

    @Test func countUpdatesWhenMalfunctionIsAppended() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)

        #expect(run.malfunctionsCount == 0)

        makeMalfunction(in: ctx, run: run, kind: .failureToFeed, count: 2)
        #expect(run.malfunctionsCount == 2)

        makeMalfunction(in: ctx, run: run, kind: .stovepipe, count: 1)
        #expect(run.malfunctionsCount == 3)
    }

    @Test func countUpdatesWhenMalfunctionIsRemoved() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)

        makeMalfunction(in: ctx, run: run, kind: .failureToFeed, count: 3)
        makeMalfunction(in: ctx, run: run, kind: .stovepipe,     count: 2)
        #expect(run.malfunctionsCount == 5)

        run.malfunctions.removeAll()
        #expect(run.malfunctionsCount == 0)
    }

    // MARK: - Always equals sum of RunMalfunction.count values

    @Test func alwaysEqualsManualSum() {
        // Belt-and-suspenders: directly verifies the invariant rather than
        // testing specific values. Catches any future change to the formula.
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)

        makeMalfunction(in: ctx, run: run, kind: .failureToFeed,    count: 4)
        makeMalfunction(in: ctx, run: run, kind: .lightStrike,      count: 1)
        makeMalfunction(in: ctx, run: run, kind: .failureToLockBack, count: 2)

        let manualSum = run.malfunctions.reduce(0) { $0 + $1.count }
        #expect(run.malfunctionsCount == manualSum)
    }

    // MARK: - Per-run isolation

    @Test func malfunctionsDoNotLeakBetweenRuns() {
        // Two runs in the same session should have independent counts.
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let runA = makeRun(in: ctx, firearm: firearm, session: session)
        let runB = makeRun(in: ctx, firearm: firearm, session: session)

        makeMalfunction(in: ctx, run: runA, kind: .stovepipe,     count: 3)
        makeMalfunction(in: ctx, run: runB, kind: .failureToFeed, count: 1)

        #expect(runA.malfunctionsCount == 3)
        #expect(runB.malfunctionsCount == 1)
    }
}
