import Testing
import Foundation
import SwiftData
@testable import RoundCount

// Full AnalyticsService coverage using real in-memory SwiftData fixtures.
// These are the tests the README promise of "analytics you can rely on" requires.

@Suite("AnalyticsService")
@MainActor
struct AnalyticsServiceTests {

    let container: ModelContainer
    let ctx: ModelContext

    init() throws {
        container = try makeTestContainer()
        ctx = ModelContext(container)
    }

    // MARK: - filteredSessions

    @Test func filteredSessions_allRange_returnsEverything() {
        let firearm = makeFirearm(in: ctx)
        makeSession(in: ctx, startedAt: utcDate(year: 2024, month: 1, day: 1))
        makeSession(in: ctx, startedAt: utcDate(year: 2025, month: 6, day: 1))
        makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 1))
        _ = firearm // suppress warning — firearm is needed for runs but sessions stand alone here

        let sessions = try! ctx.fetch(FetchDescriptor<SessionV2>())
        let result = AnalyticsService.filteredSessions(
            sessions,
            range: .all,
            reference: utcDate(year: 2026, month: 3, day: 15),
            calendar: utcCalendar
        )
        #expect(result.count == 3)
    }

    @Test func filteredSessions_excludesSessionsBeforeRange() {
        // Reference: 2026-03-15. days30 window starts 2026-02-14.
        // Session on 2026-02-01 is outside; session on 2026-03-01 is inside.
        let ref = utcDate(year: 2026, month: 3, day: 15)

        let outside = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 2, day: 1))
        let inside  = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 1))

        let sessions = [outside, inside]
        let result = AnalyticsService.filteredSessions(
            sessions, range: .days30, reference: ref, calendar: utcCalendar
        )

        #expect(result.count == 1)
        #expect(result.first?.id == inside.id)
    }

    @Test func filteredSessions_includesSessionOnBoundaryDay() {
        // A session starting exactly on the window's first day must be included.
        // days30 from 2026-03-15: start = startOfDay(2026-03-15) - 29 days = 2026-02-14
        let ref = utcDate(year: 2026, month: 3, day: 15)
        let boundary = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 2, day: 14))

        let result = AnalyticsService.filteredSessions(
            [boundary], range: .days30, reference: ref, calendar: utcCalendar
        )
        #expect(result.count == 1)
    }

    @Test func filteredSessions_emptyInput_returnsEmpty() {
        let result = AnalyticsService.filteredSessions(
            [],
            range: .days30,
            reference: utcDate(year: 2026, month: 3, day: 15),
            calendar: utcCalendar
        )
        #expect(result.isEmpty)
    }

    // MARK: - totals

    @Test func totals_emptySessions_returnsZeros() {
        let result = AnalyticsService.totals([])
        #expect(result.rounds == 0)
        #expect(result.durationSeconds == 0)
        #expect(result.malfunctions == 0)
    }

    @Test func totals_singleSession_correctSums() {
        let firearm = makeFirearm(in: ctx)
        let start = utcDate(year: 2026, month: 3, day: 1)
        let session = makeSession(in: ctx, startedAt: start, endedAt: start.addingTimeInterval(3600))

        let run = makeRun(in: ctx, firearm: firearm, session: session, rounds: 150)
        makeMalfunction(in: ctx, run: run, kind: .failureToFeed, count: 2)

        let result = AnalyticsService.totals([session])
        #expect(result.rounds == 150)
        #expect(result.durationSeconds == 3600)
        #expect(result.malfunctions == 2)
    }

    @Test func totals_multipleSessions_aggregatesAll() {
        let firearm = makeFirearm(in: ctx)

        let s1 = makeSession(in: ctx,
                             startedAt: utcDate(year: 2026, month: 3, day: 1),
                             endedAt:   utcDate(year: 2026, month: 3, day: 1).addingTimeInterval(1800))
        let r1 = makeRun(in: ctx, firearm: firearm, session: s1, rounds: 100)
        makeMalfunction(in: ctx, run: r1, kind: .stovepipe, count: 1)

        let s2 = makeSession(in: ctx,
                             startedAt: utcDate(year: 2026, month: 3, day: 8),
                             endedAt:   utcDate(year: 2026, month: 3, day: 8).addingTimeInterval(3600))
        let r2 = makeRun(in: ctx, firearm: firearm, session: s2, rounds: 200)
        makeMalfunction(in: ctx, run: r2, kind: .failureToFeed, count: 3)

        let result = AnalyticsService.totals([s1, s2])
        #expect(result.rounds == 300)
        #expect(result.durationSeconds == 5400)  // 1800 + 3600
        #expect(result.malfunctions == 4)
    }

    @Test func totals_multipleRunsPerSession_sumsAll() {
        let firearmA = makeFirearm(in: ctx, brand: "Glock", model: "19")
        let firearmB = makeFirearm(in: ctx, brand: "CZ",    model: "SP-01")
        let session  = makeSession(in: ctx,
                                   startedAt: utcDate(year: 2026, month: 3, day: 1),
                                   endedAt:   utcDate(year: 2026, month: 3, day: 1).addingTimeInterval(7200))

        makeRun(in: ctx, firearm: firearmA, session: session, rounds: 100)
        makeRun(in: ctx, firearm: firearmB, session: session, rounds: 75)

        let result = AnalyticsService.totals([session])
        #expect(result.rounds == 175)
        #expect(result.durationSeconds == 7200)
    }

    // MARK: - roundsByDay

    @Test func roundsByDay_emptySessions_returnsEmpty() {
        let result = AnalyticsService.roundsByDay([], calendar: utcCalendar)
        #expect(result.isEmpty)
    }

    @Test func roundsByDay_singleSession_oneBucket() {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 10))
        makeRun(in: ctx, firearm: firearm, session: session, rounds: 50)

        let result = AnalyticsService.roundsByDay([session], calendar: utcCalendar)

        #expect(result.count == 1)
        #expect(result[0].rounds == 50)
        #expect(utcCalendar.isDate(result[0].day, inSameDayAs: utcDate(year: 2026, month: 3, day: 10)))
    }

    @Test func roundsByDay_sessionsOnDifferentDays_separateBuckets() {
        let firearm = makeFirearm(in: ctx)

        let s1 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 10))
        makeRun(in: ctx, firearm: firearm, session: s1, rounds: 50)

        let s2 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 15))
        makeRun(in: ctx, firearm: firearm, session: s2, rounds: 100)

        let result = AnalyticsService.roundsByDay([s1, s2], calendar: utcCalendar)

        #expect(result.count == 2)
        #expect(result.reduce(0) { $0 + $1.rounds } == 150)
    }

    @Test func roundsByDay_sessionsOnSameDay_mergesToOneBucket() {
        let firearm = makeFirearm(in: ctx)
        let day = utcDate(year: 2026, month: 3, day: 10)

        // Two sessions on the same day — should collapse to a single bucket.
        let s1 = makeSession(in: ctx, startedAt: day)
        makeRun(in: ctx, firearm: firearm, session: s1, rounds: 50)

        let s2 = makeSession(in: ctx, startedAt: day.addingTimeInterval(3600))
        makeRun(in: ctx, firearm: firearm, session: s2, rounds: 75)

        let result = AnalyticsService.roundsByDay([s1, s2], calendar: utcCalendar)

        #expect(result.count == 1)
        #expect(result[0].rounds == 125)
    }

    @Test func roundsByDay_resultIsSortedAscending() {
        let firearm = makeFirearm(in: ctx)

        let s1 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 20))
        makeRun(in: ctx, firearm: firearm, session: s1, rounds: 10)

        let s2 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 5))
        makeRun(in: ctx, firearm: firearm, session: s2, rounds: 20)

        let s3 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 12))
        makeRun(in: ctx, firearm: firearm, session: s3, rounds: 30)

        let result = AnalyticsService.roundsByDay([s1, s2, s3], calendar: utcCalendar)

        #expect(result.count == 3)
        for i in 0..<result.count - 1 {
            #expect(result[i].day < result[i + 1].day)
        }
    }

    // MARK: - roundsByWeek

    @Test func roundsByWeek_sessionsInSameWeek_mergesToOneBucket() {
        let firearm = makeFirearm(in: ctx)

        // Two sessions in the same ISO week
        let s1 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 9))  // Mon
        makeRun(in: ctx, firearm: firearm, session: s1, rounds: 60)

        let s2 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 11)) // Wed
        makeRun(in: ctx, firearm: firearm, session: s2, rounds: 40)

        let result = AnalyticsService.roundsByWeek([s1, s2], calendar: utcCalendar)

        #expect(result.count == 1)
        #expect(result[0].rounds == 100)
    }

    @Test func roundsByWeek_sessionsInDifferentWeeks_separateBuckets() {
        let firearm = makeFirearm(in: ctx)

        let s1 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 2))  // week 1
        makeRun(in: ctx, firearm: firearm, session: s1, rounds: 50)

        let s2 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 16)) // week 2
        makeRun(in: ctx, firearm: firearm, session: s2, rounds: 80)

        let result = AnalyticsService.roundsByWeek([s1, s2], calendar: utcCalendar)

        #expect(result.count == 2)
        #expect(result.reduce(0) { $0 + $1.rounds } == 130)
    }

    @Test func roundsByWeek_resultIsSortedAscending() {
        let firearm = makeFirearm(in: ctx)

        let s1 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 23))
        makeRun(in: ctx, firearm: firearm, session: s1, rounds: 10)

        let s2 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 2))
        makeRun(in: ctx, firearm: firearm, session: s2, rounds: 20)

        let result = AnalyticsService.roundsByWeek([s1, s2], calendar: utcCalendar)

        #expect(result.count == 2)
        #expect(result[0].startOfWeek < result[1].startOfWeek)
    }

    // MARK: - topFirearmsByRounds

    @Test func topFirearmsByRounds_empty_returnsEmpty() {
        let result = AnalyticsService.topFirearmsByRounds([])
        #expect(result.isEmpty)
    }

    @Test func topFirearmsByRounds_ranksCorrectly() {
        let g19  = makeFirearm(in: ctx, brand: "Glock", model: "19")
        let sp01 = makeFirearm(in: ctx, brand: "CZ",    model: "SP-01")
        let p365 = makeFirearm(in: ctx, brand: "SIG",   model: "P365")

        let session = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 1))
        makeRun(in: ctx, firearm: g19,  session: session, rounds: 200)
        makeRun(in: ctx, firearm: sp01, session: session, rounds: 50)
        makeRun(in: ctx, firearm: p365, session: session, rounds: 125)

        let result = AnalyticsService.topFirearmsByRounds([session])

        #expect(result.count == 3)
        #expect(result[0].value == 200) // Glock 19
        #expect(result[1].value == 125) // SIG P365
        #expect(result[2].value == 50)  // CZ SP-01
    }

    @Test func topFirearmsByRounds_respectsLimit() {
        let session = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 1))

        for i in 1...8 {
            let f = makeFirearm(in: ctx, brand: "Brand", model: "M\(i)")
            makeRun(in: ctx, firearm: f, session: session, rounds: i * 10)
        }

        let result = AnalyticsService.topFirearmsByRounds([session], limit: 3)
        #expect(result.count == 3)
    }

    @Test func topFirearmsByRounds_aggregatesAcrossMultipleSessions() {
        let g19  = makeFirearm(in: ctx, brand: "Glock", model: "19")
        let sp01 = makeFirearm(in: ctx, brand: "CZ",    model: "SP-01")

        let s1 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 1))
        makeRun(in: ctx, firearm: g19,  session: s1, rounds: 100)
        makeRun(in: ctx, firearm: sp01, session: s1, rounds: 50)

        let s2 = makeSession(in: ctx, startedAt: utcDate(year: 2026, month: 3, day: 8))
        makeRun(in: ctx, firearm: g19,  session: s2, rounds: 150) // 100 + 150 = 250 total

        let result = AnalyticsService.topFirearmsByRounds([s1, s2])

        let g19Row = result.first(where: { $0.title == "Glock 19" })
        #expect(g19Row?.value == 250)
    }
}
