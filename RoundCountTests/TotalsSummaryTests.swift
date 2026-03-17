import Testing
@testable import RoundCount

@Suite("TotalsSummary")
struct TotalsSummaryTests {

    // MARK: - malfunctionsPerK

    @Test func malfunctionsPerK_zeroRounds_returnsZero() {
        // Guard against divide-by-zero — result must be 0, not inf or nan.
        let s = TotalsSummary(rounds: 0, durationSeconds: 0, malfunctions: 5)
        #expect(s.malfunctionsPerK == 0.0)
    }

    @Test func malfunctionsPerK_zeroMalfunctions_returnsZero() {
        let s = TotalsSummary(rounds: 1_000, durationSeconds: 0, malfunctions: 0)
        #expect(s.malfunctionsPerK == 0.0)
    }

    @Test func malfunctionsPerK_1000rounds_1malf_returns1() {
        let s = TotalsSummary(rounds: 1_000, durationSeconds: 0, malfunctions: 1)
        #expect(s.malfunctionsPerK == 1.0)
    }

    @Test func malfunctionsPerK_500rounds_2malf_returns4() {
        // 2 / 500 * 1000 = 4.0
        let s = TotalsSummary(rounds: 500, durationSeconds: 0, malfunctions: 2)
        #expect(s.malfunctionsPerK == 4.0)
    }

    @Test func malfunctionsPerK_250rounds_1malf_returns4() {
        // 1 / 250 * 1000 = 4.0
        let s = TotalsSummary(rounds: 250, durationSeconds: 0, malfunctions: 1)
        #expect(s.malfunctionsPerK == 4.0)
    }

    // MARK: - durationMinutesRounded

    @Test func durationMinutes_zeroSeconds_isZero() {
        let s = TotalsSummary(rounds: 0, durationSeconds: 0, malfunctions: 0)
        #expect(s.durationMinutesRounded == 0)
    }

    @Test func durationMinutes_59seconds_is1() {
        // 59 / 60 = 0.983... → rounds to 1
        let s = TotalsSummary(rounds: 0, durationSeconds: 59, malfunctions: 0)
        #expect(s.durationMinutesRounded == 1)
    }

    @Test func durationMinutes_60seconds_is1() {
        let s = TotalsSummary(rounds: 0, durationSeconds: 60, malfunctions: 0)
        #expect(s.durationMinutesRounded == 1)
    }

    @Test func durationMinutes_90seconds_is2() {
        // 90 / 60 = 1.5 → rounds half-away-from-zero to 2
        let s = TotalsSummary(rounds: 0, durationSeconds: 90, malfunctions: 0)
        #expect(s.durationMinutesRounded == 2)
    }

    @Test func durationMinutes_3600seconds_is60() {
        let s = TotalsSummary(rounds: 0, durationSeconds: 3_600, malfunctions: 0)
        #expect(s.durationMinutesRounded == 60)
    }

    @Test func durationMinutes_isNeverNegative() {
        // durationSeconds shouldn't be negative in practice, but the guard is worth checking.
        let s = TotalsSummary(rounds: 0, durationSeconds: 0, malfunctions: 0)
        #expect(s.durationMinutesRounded >= 0)
    }
}
