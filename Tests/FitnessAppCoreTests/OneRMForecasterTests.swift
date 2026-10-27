import XCTest
@testable import FitnessAppCore

/// Audit Fix 4: `OneRMForecaster` powers the Dashboard's "Compound-Lift-Trend"
/// 4-week projection but had zero test coverage, unlike its sibling
/// `BodyCalculations.projectWeightTrend` (see `BodyCalculationsTests`), which
/// this file mirrors in style and structure.
final class OneRMForecasterTests: XCTestCase {

    private func day(_ offsetDays: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: TimeInterval(offsetDays) * 24 * 3600)
    }

    private func week(_ offsetWeeks: Int) -> Date {
        day(offsetWeeks * 7)
    }

    // MARK: projectOneRM — happy path

    func testProjectOneRMExtendsAPerfectLinearTrend() {
        // 100 -> 105 -> 110 -> 115 kg, exactly +5 kg/week. 4 weeks ahead from
        // the last sample (week 3): 115 + 5*4 = 135.
        let samples = [
            OneRMSample(date: week(0), oneRM: 100),
            OneRMSample(date: week(1), oneRM: 105),
            OneRMSample(date: week(2), oneRM: 110),
            OneRMSample(date: week(3), oneRM: 115)
        ]
        let projected = OneRMForecaster.projectOneRM(samples: samples, weeksAhead: 4)
        XCTAssertNotNil(projected)
        XCTAssertEqual(projected!, 135, accuracy: 1e-9)
    }

    func testProjectOneRMReturnsNilForFewerThanThreeSamples() {
        let samples = [
            OneRMSample(date: week(0), oneRM: 100),
            OneRMSample(date: week(1), oneRM: 105)
        ]
        XCTAssertNil(OneRMForecaster.projectOneRM(samples: samples, weeksAhead: 4))
    }

    func testProjectOneRMReturnsNilWhenAllSamplesShareTheSameDate() {
        // Reliable values (low RSD), but zero date span — the slope would be
        // numerically meaningless, not just small.
        let sameDate = week(0)
        let samples = [
            OneRMSample(date: sameDate, oneRM: 100),
            OneRMSample(date: sameDate, oneRM: 101),
            OneRMSample(date: sameDate, oneRM: 102)
        ]
        XCTAssertNil(OneRMForecaster.projectOneRM(samples: samples, weeksAhead: 4))
    }

    func testProjectOneRMReturnsNilWhenRelativeStandardDeviationExceeds15Percent() {
        // 100 / 150 / 50 — wild swings (RSD ~41%), e.g. a broken log or a
        // deload week mixed into the window.
        let samples = [
            OneRMSample(date: week(0), oneRM: 100),
            OneRMSample(date: week(1), oneRM: 150),
            OneRMSample(date: week(2), oneRM: 50)
        ]
        XCTAssertNil(OneRMForecaster.projectOneRM(samples: samples, weeksAhead: 4))
    }

    // MARK: Slope clamp

    func testProjectOneRMClampsSlopeAt20KgPerWeek() {
        // 300 -> 325 -> 350 kg: a perfectly linear +25 kg/week raw slope
        // (RSD ~6.3%, well under the 15% unreliability threshold at this
        // baseline) — clamped to +20 kg/week before projecting.
        // Clamped: 325 + 20*(6-1) = 425. Unclamped would be 325 + 25*5 = 450.
        let samples = [
            OneRMSample(date: week(0), oneRM: 300),
            OneRMSample(date: week(1), oneRM: 325),
            OneRMSample(date: week(2), oneRM: 350)
        ]
        let projected = OneRMForecaster.projectOneRM(samples: samples, weeksAhead: 4)
        XCTAssertNotNil(projected)
        XCTAssertEqual(projected!, 425, accuracy: 1e-9,
                       "Raw +25 kg/week slope must be clamped to +20 before projecting")
    }

    // MARK: Sanity range

    func testProjectOneRMReturnsNilWhenProjectionFallsBelowSanityRange() {
        // 100 -> 98 -> 96 kg: a gentle, reliable -2 kg/week decline
        // (slope well under the clamp, RSD ~1.7%). Projected 50 weeks out:
        // 98 - 2*(52-1) = -4, below the 20 kg sanity floor.
        let samples = [
            OneRMSample(date: week(0), oneRM: 100),
            OneRMSample(date: week(1), oneRM: 98),
            OneRMSample(date: week(2), oneRM: 96)
        ]
        XCTAssertNil(OneRMForecaster.projectOneRM(samples: samples, weeksAhead: 50))
    }

    // MARK: Recent-samples window

    func testProjectOneRMIgnoresSamplesOlderThanTheRecentWindow() {
        // An ancient outlier (week -100, 9999 kg) must be dropped once there
        // are more than 6 samples — only the 6 most recent (a clean +5
        // kg/week trend) should drive the regression.
        let outlier = OneRMSample(date: week(-100), oneRM: 9999)
        let recent = (0...5).map { OneRMSample(date: week($0), oneRM: 100 + Double($0) * 5) }

        let withOutlier = OneRMForecaster.projectOneRM(samples: [outlier] + recent, weeksAhead: 4)
        let withoutOutlier = OneRMForecaster.projectOneRM(samples: recent, weeksAhead: 4)

        XCTAssertNotNil(withOutlier)
        XCTAssertEqual(withOutlier!, 145, accuracy: 1e-9)
        XCTAssertEqual(withOutlier, withoutOutlier,
                       "The 7th (oldest) sample must be excluded from the regression window")
    }

    // MARK: forecastPoint

    func testForecastPointReturnsCorrectlyDatedSample() {
        let samples = [
            OneRMSample(date: week(0), oneRM: 100),
            OneRMSample(date: week(1), oneRM: 105),
            OneRMSample(date: week(2), oneRM: 110),
            OneRMSample(date: week(3), oneRM: 115)
        ]
        let now = week(10)
        let point = OneRMForecaster.forecastPoint(samples: samples, weeksAhead: 4, now: now)

        XCTAssertNotNil(point)
        XCTAssertEqual(point!.oneRM, 135, accuracy: 1e-9)
        let expectedDate = now.addingTimeInterval(4 * 7 * 24 * 3600)
        XCTAssertEqual(point!.date, expectedDate)
    }

    func testForecastPointReturnsNilWhenProjectionIsNotPossible() {
        let samples = [
            OneRMSample(date: week(0), oneRM: 100),
            OneRMSample(date: week(1), oneRM: 105)
        ]
        XCTAssertNil(OneRMForecaster.forecastPoint(samples: samples, weeksAhead: 4))
    }
}
