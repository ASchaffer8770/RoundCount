// TestFactory.swift
// Shared helpers for Layer 3 (SwiftData in-memory) tests.
//
// Each @Suite gets a fresh ModelContainer and ModelContext via init() throws,
// so every test runs in full isolation with no shared state.

import Foundation
import SwiftData
@testable import RoundCount

// MARK: - Container

/// Mirrors the production schema exactly. isStoredInMemoryOnly keeps tests fast
/// and leaves no files behind on disk.
func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([
        Firearm.self,
        FirearmMagazine.self,
        FirearmRun.self,
        RunMalfunction.self,
        FirearmSetup.self,
        GearItem.self,
        SessionV2.self,
        AmmoProduct.self,
        SessionPhoto.self,
    ])
    return try ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
    )
}

// MARK: - Fixture factories
//
// Each factory inserts the object into the context and returns it.
// Callers can ignore the return value when the side-effect is all that matters.

@discardableResult
func makeFirearm(
    in ctx: ModelContext,
    brand: String = "Glock",
    model: String = "19",
    caliber: String = "9mm"
) -> Firearm {
    let f = Firearm(brand: brand, model: model, caliber: caliber)
    ctx.insert(f)
    return f
}

@discardableResult
func makeSession(
    in ctx: ModelContext,
    startedAt: Date = Date(),
    endedAt: Date? = nil
) -> SessionV2 {
    let s = SessionV2(startedAt: startedAt, endedAt: endedAt)
    ctx.insert(s)
    return s
}

@discardableResult
func makeRun(
    in ctx: ModelContext,
    firearm: Firearm,
    session: SessionV2,
    rounds: Int = 0,
    startedAt: Date? = nil,
    endedAt: Date? = nil
) -> FirearmRun {
    let r = FirearmRun(
        firearm: firearm,
        startedAt: startedAt ?? session.startedAt,
        endedAt: endedAt,
        rounds: rounds,
        session: session
    )
    ctx.insert(r)
    session.runs.append(r)
    return r
}

@discardableResult
func makeMalfunction(
    in ctx: ModelContext,
    run: FirearmRun,
    kind: MalfunctionKind = .failureToFeed,
    count: Int = 1
) -> RunMalfunction {
    let m = RunMalfunction(run: run, kind: kind, count: count)
    ctx.insert(m)
    run.malfunctions.append(m)
    return m
}

@discardableResult
func makePhoto(
    in ctx: ModelContext,
    run: FirearmRun,
    tag: SessionPhotoTag = .target
) -> SessionPhoto {
    let p = SessionPhoto(run: run, imageData: Data("photo".utf8), tag: tag)
    ctx.insert(p)
    run.photos.append(p)
    return p
}

// MARK: - Date helpers

/// Returns midnight UTC on the given date components.
func utcDate(year: Int, month: Int, day: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal.date(from: DateComponents(year: year, month: month, day: day))!
}

let utcCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()
