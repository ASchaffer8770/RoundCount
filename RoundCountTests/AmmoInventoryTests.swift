import Testing
import SwiftData
@testable import RoundCount

@Suite("AmmoProduct — Inventory")
struct AmmoInventoryTests {

    // MARK: - isTrackingInventory

    @Test func notTracking_whenRoundsOnHandIsNil() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)
        let ammo = makeAmmoProduct(in: ctx)
        // roundsOnHand defaults to nil in factory
        #expect(ammo.isTrackingInventory == false)
    }

    @Test func tracking_whenRoundsOnHandIsZero() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)
        let ammo = makeAmmoProduct(in: ctx, roundsOnHand: 0)
        #expect(ammo.isTrackingInventory == true)
    }

    @Test func tracking_whenRoundsOnHandIsPositive() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)
        let ammo = makeAmmoProduct(in: ctx, roundsOnHand: 200)
        #expect(ammo.isTrackingInventory == true)
    }

    // MARK: - inventoryDisplayText

    @Test func displayText_notTracking() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)
        let ammo = makeAmmoProduct(in: ctx)
        #expect(ammo.inventoryDisplayText == "—")
    }

    @Test func displayText_outOfStock() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)
        let ammo = makeAmmoProduct(in: ctx, roundsOnHand: 0)
        #expect(ammo.inventoryDisplayText == "Out of stock")
    }

    @Test func displayText_singularRound() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)
        let ammo = makeAmmoProduct(in: ctx, roundsOnHand: 1)
        #expect(ammo.inventoryDisplayText == "1 round")
    }

    @Test func displayText_pluralRounds() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)
        let ammo = makeAmmoProduct(in: ctx, roundsOnHand: 150)
        #expect(ammo.inventoryDisplayText == "150 rounds")
    }

    // MARK: - totalRoundsOnHand (multi-product)

    @Test func totalOnHand_sumIgnoresNonTracked() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)

        let a1 = makeAmmoProduct(in: ctx, brand: "Federal",    roundsOnHand: 100)
        let a2 = makeAmmoProduct(in: ctx, brand: "Winchester", roundsOnHand: 200)
        let a3 = makeAmmoProduct(in: ctx, brand: "CCI",        roundsOnHand: nil)

        let total = [a1, a2, a3].compactMap(\.roundsOnHand).reduce(0, +)
        #expect(total == 300)
    }

    @Test func totalOnHand_allNilIsZero() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)

        let a1 = makeAmmoProduct(in: ctx, brand: "Federal",    roundsOnHand: nil)
        let a2 = makeAmmoProduct(in: ctx, brand: "Winchester", roundsOnHand: nil)

        let total = [a1, a2].compactMap(\.roundsOnHand).reduce(0, +)
        #expect(total == 0)
    }

    // MARK: - Persistence round-trip

    @Test func roundsOnHand_persistsAndReloads() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)

        let ammo = makeAmmoProduct(in: ctx, roundsOnHand: 500)
        try ctx.save()

        let descriptor = FetchDescriptor<AmmoProduct>()
        let loaded = try ctx.fetch(descriptor)
        #expect(loaded.count == 1)
        #expect(loaded[0].roundsOnHand == 500)
    }

    @Test func roundsOnHand_nilPersists() throws {
        let container = try makeTestContainer()
        let ctx = ModelContext(container)

        makeAmmoProduct(in: ctx, roundsOnHand: nil)
        try ctx.save()

        let descriptor = FetchDescriptor<AmmoProduct>()
        let loaded = try ctx.fetch(descriptor)
        #expect(loaded[0].roundsOnHand == nil)
        #expect(loaded[0].isTrackingInventory == false)
    }
}
