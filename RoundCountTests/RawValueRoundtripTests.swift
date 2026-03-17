import Testing
@testable import RoundCount

// These tests guard against typos in raw string values and accidental case renames.
// If a raw value changes between releases, saved SwiftData data will silently
// fall back to `.other` / nil — these tests make that a build-time failure instead.

@Suite("Raw value roundtrips")
struct RawValueRoundtripTests {

    @Test("MalfunctionKind", arguments: MalfunctionKind.allCases)
    func malfunctionKindRoundtrip(kind: MalfunctionKind) {
        #expect(MalfunctionKind(rawValue: kind.rawValue) == kind)
    }

    @Test("SessionPhotoTag", arguments: SessionPhotoTag.allCases)
    func sessionPhotoTagRoundtrip(tag: SessionPhotoTag) {
        #expect(SessionPhotoTag(rawValue: tag.rawValue) == tag)
    }

    @Test("Feature", arguments: Feature.allCases)
    func featureRoundtrip(feature: Feature) {
        #expect(Feature(rawValue: feature.rawValue) == feature)
    }

    @Test("FirearmClass", arguments: FirearmClass.allCases)
    func firearmClassRoundtrip(fc: FirearmClass) {
        #expect(FirearmClass(rawValue: fc.rawValue) == fc)
    }

    @Test("AnalyticsTimeRange", arguments: AnalyticsTimeRange.allCases)
    func analyticsTimeRangeRoundtrip(range: AnalyticsTimeRange) {
        #expect(AnalyticsTimeRange(rawValue: range.rawValue) == range)
    }
}
