import Testing
import SwiftData
@testable import RoundCount

// Verifies that SwiftData's deleteRule: .cascade actually fires for every
// relationship that declares it. A misconfigured rule produces silent data
// corruption (orphaned rows) that only shows up later as wrong analytics.

@Suite("Cascade delete rules")
@MainActor
struct CascadeDeleteTests {

    let container: ModelContainer
    let ctx: ModelContext

    init() throws {
        container = try makeTestContainer()
        ctx = ModelContext(container)
    }

    // MARK: - SessionV2 → FirearmRun

    @Test func deletingSession_removesItsRuns() throws {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        makeRun(in: ctx, firearm: firearm, session: session)
        makeRun(in: ctx, firearm: firearm, session: session)
        try ctx.save()

        ctx.delete(session)
        try ctx.save()

        let remaining = try ctx.fetch(FetchDescriptor<FirearmRun>())
        #expect(remaining.isEmpty)
    }

    @Test func deletingSession_doesNotDeleteFirearm() throws {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        makeRun(in: ctx, firearm: firearm, session: session)
        try ctx.save()

        ctx.delete(session)
        try ctx.save()

        let firearms = try ctx.fetch(FetchDescriptor<Firearm>())
        #expect(firearms.count == 1)
    }

    // MARK: - FirearmRun → RunMalfunction

    @Test func deletingRun_removesItsMalfunctions() throws {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)
        makeMalfunction(in: ctx, run: run, kind: .failureToFeed, count: 2)
        makeMalfunction(in: ctx, run: run, kind: .stovepipe,     count: 1)
        try ctx.save()

        ctx.delete(run)
        try ctx.save()

        let remaining = try ctx.fetch(FetchDescriptor<RunMalfunction>())
        #expect(remaining.isEmpty)
    }

    @Test func deletingSession_alsoRemovesMalfunctionsViaRunCascade() throws {
        // Two-hop cascade: session → run → malfunctions
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)
        makeMalfunction(in: ctx, run: run, kind: .failureToFeed, count: 3)
        try ctx.save()

        ctx.delete(session)
        try ctx.save()

        let runs  = try ctx.fetch(FetchDescriptor<FirearmRun>())
        let malfs = try ctx.fetch(FetchDescriptor<RunMalfunction>())
        #expect(runs.isEmpty)
        #expect(malfs.isEmpty)
    }

    // MARK: - FirearmRun → SessionPhoto

    @Test func deletingRun_removesItsPhotos() throws {
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)
        makePhoto(in: ctx, run: run, tag: .target)
        makePhoto(in: ctx, run: run, tag: .malfunction)
        try ctx.save()

        ctx.delete(run)
        try ctx.save()

        let remaining = try ctx.fetch(FetchDescriptor<SessionPhoto>())
        #expect(remaining.isEmpty)
    }

    @Test func deletingSession_alsoRemovesPhotosViaRunCascade() throws {
        // Two-hop cascade: session → run → photos
        let firearm = makeFirearm(in: ctx)
        let session = makeSession(in: ctx)
        let run = makeRun(in: ctx, firearm: firearm, session: session)
        makePhoto(in: ctx, run: run)
        try ctx.save()

        ctx.delete(session)
        try ctx.save()

        let photos = try ctx.fetch(FetchDescriptor<SessionPhoto>())
        #expect(photos.isEmpty)
    }

    // MARK: - Firearm → FirearmMagazine

    @Test func deletingFirearm_removesItsMagazines() throws {
        let firearm = makeFirearm(in: ctx)
        let mag = FirearmMagazine(firearm: firearm, capacity: 17)
        ctx.insert(mag)
        firearm.magazines.append(mag)
        try ctx.save()

        ctx.delete(firearm)
        try ctx.save()

        let remaining = try ctx.fetch(FetchDescriptor<FirearmMagazine>())
        #expect(remaining.isEmpty)
    }

    // MARK: - Isolation between sessions

    @Test func deletingOneSession_leavesOtherSessionsIntact() throws {
        let firearm = makeFirearm(in: ctx)

        let sessionA = makeSession(in: ctx)
        makeRun(in: ctx, firearm: firearm, session: sessionA)

        let sessionB = makeSession(in: ctx)
        let runB = makeRun(in: ctx, firearm: firearm, session: sessionB)
        makeMalfunction(in: ctx, run: runB, kind: .stovepipe, count: 1)
        try ctx.save()

        ctx.delete(sessionA)
        try ctx.save()

        let sessions = try ctx.fetch(FetchDescriptor<SessionV2>())
        let runs     = try ctx.fetch(FetchDescriptor<FirearmRun>())
        let malfs    = try ctx.fetch(FetchDescriptor<RunMalfunction>())

        #expect(sessions.count == 1)
        #expect(runs.count    == 1)
        #expect(malfs.count   == 1)
    }

    @Test func deletingAllSessions_leavesFirearmsIntact() throws {
        let firearm = makeFirearm(in: ctx)
        let sessionA = makeSession(in: ctx)
        makeRun(in: ctx, firearm: firearm, session: sessionA)
        let sessionB = makeSession(in: ctx)
        makeRun(in: ctx, firearm: firearm, session: sessionB)
        try ctx.save()

        for s in try ctx.fetch(FetchDescriptor<SessionV2>()) {
            ctx.delete(s)
        }
        try ctx.save()

        let firearms = try ctx.fetch(FetchDescriptor<Firearm>())
        #expect(firearms.count == 1)
    }
}
