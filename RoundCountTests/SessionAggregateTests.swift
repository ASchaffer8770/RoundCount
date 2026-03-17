import Testing
import Foundation
import SwiftData
@testable import RoundCount

// Tests for SessionV2's computed aggregate properties.
// These are the values that feed the dashboard, session detail, and analytics —
// wrong numbers here propagate everywhere.

@Suite("SessionV2 aggregates")
@MainActor
struct SessionAggregateTests {

    let container: ModelContainer
    let ctx: ModelContext

    init() throws {
        container = try makeTestContainer()
        ctx = ModelContext(container)
    }

    // MARK: - totalRounds

    @Test func totalRounds_noRuns_isZero() {
        let session = makeSession(in: ctx)
        #expect(session.totalRounds == 0)
    }

    @Test func totalRounds_singleRun() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        makeRun(in: ctx, firearm: firearm, session: session, rounds: 50)

        #expect(session.totalRounds == 50)
    }

    @Test func totalRounds_aggregatesAcrossMultipleRuns() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        makeRun(in: ctx, firearm: firearm, session: session, rounds: 50)
        makeRun(in: ctx, firearm: firearm, session: session, rounds: 100)
        makeRun(in: ctx, firearm: firearm, session: session, rounds: 25)

        #expect(session.totalRounds == 175)
    }

    @Test func totalRounds_updatesWhenRunRoundsChanges() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session, rounds: 30)

        #expect(session.totalRounds == 30)

        run.rounds = 60
        #expect(session.totalRounds == 60)
    }

    @Test func totalRounds_multipleFirearms_sumsAll() {
        let g19  = makeFirearm(in: ctx, brand: "Glock",  model: "19")
        let sp01 = makeFirearm(in: ctx, brand: "CZ",     model: "SP-01")
        let session = makeSession(in: ctx)

        makeRun(in: ctx, firearm: g19,  session: session, rounds: 100)
        makeRun(in: ctx, firearm: sp01, session: session, rounds: 75)

        #expect(session.totalRounds == 175)
    }

    // MARK: - totalMalfunctions

    @Test func totalMalfunctions_noRuns_isZero() {
        let session = makeSession(in: ctx)
        #expect(session.totalMalfunctions == 0)
    }

    @Test func totalMalfunctions_singleRunNoMalfunctions_isZero() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        makeRun(in: ctx, firearm: firearm, session: session, rounds: 100)

        #expect(session.totalMalfunctions == 0)
    }

    @Test func totalMalfunctions_aggregatesAcrossRuns() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)

        let runA = makeRun(in: ctx, firearm: firearm, session: session)
        makeMalfunction(in: ctx, run: runA, kind: .failureToFeed, count: 2)

        let runB = makeRun(in: ctx, firearm: firearm, session: session)
        makeMalfunction(in: ctx, run: runB, kind: .stovepipe,     count: 3)
        makeMalfunction(in: ctx, run: runB, kind: .doubleFeed,    count: 1)

        // runA: 2, runB: 3+1=4 → total: 6
        #expect(session.totalMalfunctions == 6)
    }

    @Test func totalMalfunctions_updatesWhenMalfunctionAdded() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)

        #expect(session.totalMalfunctions == 0)

        makeMalfunction(in: ctx, run: run, kind: .failureToFeed, count: 1)
        #expect(session.totalMalfunctions == 1)

        makeMalfunction(in: ctx, run: run, kind: .stovepipe, count: 2)
        #expect(session.totalMalfunctions == 3)
    }

    // MARK: - durationSeconds

    @Test func durationSeconds_withStartAndEnd_isCorrect() {
        let start = utcDate(year: 2026, month: 3, day: 15)
        let end   = start.addingTimeInterval(3600) // 1 hour later
        let session = makeSession(in: ctx, startedAt: start, endedAt: end)

        #expect(session.durationSeconds == 3600)
    }

    @Test func durationSeconds_neverNegative() {
        // endedAt before startedAt should not produce a negative duration.
        let start = utcDate(year: 2026, month: 3, day: 15)
        let end   = start.addingTimeInterval(-60) // 1 minute BEFORE start (bad data)
        let session = makeSession(in: ctx, startedAt: start, endedAt: end)

        #expect(session.durationSeconds >= 0)
    }

    @Test func durationSeconds_zeroLengthSession_isZero() {
        let now = utcDate(year: 2026, month: 6, day: 1)
        let session = makeSession(in: ctx, startedAt: now, endedAt: now)

        #expect(session.durationSeconds == 0)
    }
}
