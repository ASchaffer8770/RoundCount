import Testing
import Foundation
@testable import RoundCount

@Suite("AnalyticsTimeRange")
struct AnalyticsTimeRangeTests {

    // Fixed reference for deterministic date math.
    // UTC calendar eliminates DST surprises on CI or different-timezone machines.
    let calendar: Calendar
    let reference: Date  // 2026-06-15 12:00:00 UTC — mid-year, well away from year/month boundaries

    init() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        calendar = cal

        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 15; comps.hour = 12
        reference = try #require(cal.date(from: comps))
    }

    // MARK: - .all

    @Test func all_returnsNil() {
        #expect(AnalyticsTimeRange.all.startDate(reference: reference, calendar: calendar) == nil)
    }

    // MARK: - Correct offsets from start-of-today

    @Test func week_startsSixDaysBeforeStartOfToday() throws {
        let start = try #require(AnalyticsTimeRange.week.startDate(reference: reference, calendar: calendar))
        let startOfToday = calendar.startOfDay(for: reference)
        let expected = try #require(calendar.date(byAdding: .day, value: -6, to: startOfToday))
        #expect(start == expected)
    }

    @Test func days30_starts29DaysBeforeStartOfToday() throws {
        let start = try #require(AnalyticsTimeRange.days30.startDate(reference: reference, calendar: calendar))
        let startOfToday = calendar.startOfDay(for: reference)
        let expected = try #require(calendar.date(byAdding: .day, value: -29, to: startOfToday))
        #expect(start == expected)
    }

    @Test func days90_starts89DaysBeforeStartOfToday() throws {
        let start = try #require(AnalyticsTimeRange.days90.startDate(reference: reference, calendar: calendar))
        let startOfToday = calendar.startOfDay(for: reference)
        let expected = try #require(calendar.date(byAdding: .day, value: -89, to: startOfToday))
        #expect(start == expected)
    }

    // MARK: - YTD

    @Test func ytd_startsOnJan1OfReferenceYear() throws {
        let start = try #require(AnalyticsTimeRange.ytd.startDate(reference: reference, calendar: calendar))
        let jan1 = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        #expect(start == jan1)
    }

    @Test func ytd_inJanuary_stillReturnsJan1() throws {
        // Edge case: reference is already in January; should still return Jan 1 of that year.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 10; comps.hour = 9
        let janRef = try #require(calendar.date(from: comps))

        let start = try #require(AnalyticsTimeRange.ytd.startDate(reference: janRef, calendar: calendar))
        let jan1 = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        #expect(start == jan1)
    }

    @Test func ytd_onJan1_returnsJan1ItselF() throws {
        // Edge case: reference IS Jan 1 — startDate should equal the reference day.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 1; comps.hour = 0
        let jan1Ref = try #require(calendar.date(from: comps))

        let start = try #require(AnalyticsTimeRange.ytd.startDate(reference: jan1Ref, calendar: calendar))
        let jan1 = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        #expect(start == jan1)
    }

    // MARK: - Result is always midnight (start of day)

    @Test func startDate_isAlwaysStartOfDay() throws {
        // reference has a non-zero time component; all finite ranges should return midnight.
        for range in AnalyticsTimeRange.allCases where range != .all {
            let start = try #require(range.startDate(reference: reference, calendar: calendar))
            let comps = calendar.dateComponents([.hour, .minute, .second], from: start)
            #expect(comps.hour == 0, "range \(range) hour should be 0")
            #expect(comps.minute == 0, "range \(range) minute should be 0")
            #expect(comps.second == 0, "range \(range) second should be 0")
        }
    }

    // MARK: - Each case produces a unique start date

    @Test func allCases_produceDifferentStartDates() throws {
        let finiteCases = AnalyticsTimeRange.allCases.filter { $0 != .all }
        let dates = try finiteCases.map {
            try #require($0.startDate(reference: reference, calendar: calendar))
        }
        #expect(Set(dates).count == finiteCases.count)
    }
}
