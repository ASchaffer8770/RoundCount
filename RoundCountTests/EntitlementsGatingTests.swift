import Testing
@testable import RoundCount

@Suite("Entitlements — gateAddFirearm")
@MainActor
struct EntitlementsGatingTests {

    // Each test creates a fresh Entitlements and sets tier explicitly so tests
    // are isolated from whatever UserDefaults may persist between runs.

    // MARK: - Free tier

    @Test func free_countZero_isAllowed() {
        let e = Entitlements()
        e.setTier(.free)
        #expect(e.gateAddFirearm(currentCount: 0) == .allowed)
    }

    @Test func free_countBelowLimit_isAllowed() {
        let e = Entitlements()
        e.setTier(.free)
        #expect(e.gateAddFirearm(currentCount: e.freeFirearmLimit - 1) == .allowed)
    }

    @Test func free_countAtLimit_isLimitReached() {
        let e = Entitlements()
        e.setTier(.free)
        let result = e.gateAddFirearm(currentCount: e.freeFirearmLimit)
        guard case .limitReached(let feature, _) = result else {
            Issue.record("Expected .limitReached, got \(result)")
            return
        }
        #expect(feature == .unlimitedFirearms)
    }

    @Test func free_countWellAboveLimit_isLimitReached() {
        // Defensive: if somehow the count is already beyond the limit, still gate.
        let e = Entitlements()
        e.setTier(.free)
        let result = e.gateAddFirearm(currentCount: e.freeFirearmLimit + 10)
        guard case .limitReached(let feature, _) = result else {
            Issue.record("Expected .limitReached, got \(result)")
            return
        }
        #expect(feature == .unlimitedFirearms)
    }

    @Test func free_limitReachedMessage_mentionsLimit() {
        // The user-facing message should include the numeric limit so it's informative.
        let e = Entitlements()
        e.setTier(.free)
        let result = e.gateAddFirearm(currentCount: e.freeFirearmLimit)
        guard case .limitReached(_, let message) = result else {
            Issue.record("Expected .limitReached, got \(result)")
            return
        }
        #expect(message.contains("\(e.freeFirearmLimit)"))
    }

    // MARK: - Pro tier

    @Test func pro_countZero_isAllowed() {
        let e = Entitlements()
        e.setTier(.pro)
        #expect(e.gateAddFirearm(currentCount: 0) == .allowed)
    }

    @Test func pro_countAtFreeLimit_isStillAllowed() {
        // Pro users are never blocked by the free limit.
        let e = Entitlements()
        e.setTier(.pro)
        #expect(e.gateAddFirearm(currentCount: e.freeFirearmLimit) == .allowed)
    }

    @Test func pro_largeCount_isAllowed() {
        let e = Entitlements()
        e.setTier(.pro)
        #expect(e.gateAddFirearm(currentCount: 999) == .allowed)
    }
}
