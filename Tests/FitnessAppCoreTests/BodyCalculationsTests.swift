import XCTest
@testable import FitnessAppCore

private struct StubSample: WeightSample {
    let date: Date
    let weightKg: Double
}

final class BodyCalculationsTests: XCTestCase {

    // MARK: BMI

    func testBmiExactForRoundInputs() {
        // 80 kg / (2.0 m)^2 = 20.0 exactly
        XCTAssertEqual(BodyCalculations.bmi(weightKg: 80, heightCm: 200), 20.0, accuracy: 1e-12)
    }

    func testBmiTypicalAdult() {
        // 80 kg / 1.8^2 = 80 / 3.24 = 24.6913580...
        XCTAssertEqual(BodyCalculations.bmi(weightKg: 80, heightCm: 180), 24.691358024691358, accuracy: 1e-9)
    }

    // MARK: Navy KFA

    func testNavyMaleProducesPositiveBodyFat() {
        // Standard male reference: 180 cm, neck 38 cm, waist 88 cm. Expect ~18-19 %.
        let bf = BodyCalculations.navyBodyFat(profile: .male, heightCm: 180, neckCm: 38, waistCm: 88)
        XCTAssertNotNil(bf)
        XCTAssertEqual(bf!, 18.5, accuracy: 0.5)
    }

    func testNavyMaleMatchesFormulaConstants() {
        // Recompute the Hodgdon formula explicitly using Swift log10 — proves the
        // implementation didn't drift the constants. If this fails, the constants moved.
        let h = 180.0 / 2.54, n = 38.0 / 2.54, w = 88.0 / 2.54
        let expected = 86.010 * log10(w - n) - 70.041 * log10(h) + 36.76
        let actual = BodyCalculations.navyBodyFat(profile: .male, heightCm: 180, neckCm: 38, waistCm: 88)!
        XCTAssertEqual(actual, expected, accuracy: 1e-12)
    }

    func testNavyFemaleRequiresHip() {
        XCTAssertNil(BodyCalculations.navyBodyFat(profile: .female, heightCm: 170, neckCm: 33, waistCm: 75, hipCm: nil))
    }

    func testNavyFemaleProducesPositiveBodyFat() {
        let bf = BodyCalculations.navyBodyFat(profile: .female, heightCm: 170, neckCm: 33, waistCm: 75, hipCm: 95)
        XCTAssertNotNil(bf)
        XCTAssertEqual(bf!, 26.0, accuracy: 2.0)
    }

    func testNavyReturnsNilWhenWaistMinusNeckIsNonPositive() {
        // waist <= neck is geometrically impossible — must return nil rather than NaN/-Inf.
        XCTAssertNil(BodyCalculations.navyBodyFat(profile: .male, heightCm: 180, neckCm: 50, waistCm: 50))
    }

    // MARK: Deurenberg

    func testDeurenbergMaleRoundInputs() {
        // 1.20*20 + 0.23*30 - 10.8*1 - 5.4 = 24 + 6.9 - 10.8 - 5.4 = 14.7
        XCTAssertEqual(BodyCalculations.deurenbergBodyFat(bmi: 20, ageYears: 30, profile: .male),
                       14.7, accuracy: 1e-12)
    }

    func testDeurenbergFemaleRoundInputs() {
        // 1.20*20 + 0.23*30 - 0 - 5.4 = 24 + 6.9 - 5.4 = 25.5
        XCTAssertEqual(BodyCalculations.deurenbergBodyFat(bmi: 20, ageYears: 30, profile: .female),
                       25.5, accuracy: 1e-12)
    }

    // MARK: FFM / FFMI

    func testFatFreeMass() {
        XCTAssertEqual(BodyCalculations.fatFreeMass(weightKg: 80, bodyFatPercentage: 20), 64.0, accuracy: 1e-12)
    }

    func testFfmiExact() {
        // 64.8 kg / 1.8^2 = 64.8 / 3.24 = 20.0
        XCTAssertEqual(BodyCalculations.ffmi(fatFreeMassKg: 64.8, heightCm: 180), 20.0, accuracy: 1e-12)
    }

    func testNormalizedFfmiIdentityAt180cm() {
        // At 180 cm the (1.8 - heightM) term is zero, so normalized == raw.
        XCTAssertEqual(BodyCalculations.normalizedFfmi(ffmi: 20, heightCm: 180), 20.0, accuracy: 1e-12)
    }

    func testNormalizedFfmiAdjustsForShorterUser() {
        // 170 cm: 20 + 6.1 * (1.8 - 1.7) = 20 + 0.61 = 20.61
        XCTAssertEqual(BodyCalculations.normalizedFfmi(ffmi: 20, heightCm: 170), 20.61, accuracy: 1e-9)
    }

    // MARK: WHR

    func testWhrTypical() {
        XCTAssertEqual(BodyCalculations.whr(waistCm: 80, hipCm: 100), 0.8, accuracy: 1e-12)
    }

    func testWhrGuardsZeroHip() {
        XCTAssertEqual(BodyCalculations.whr(waistCm: 80, hipCm: 0), 0.0, accuracy: 1e-12)
    }

    // MARK: BMR

    func testBmrMifflinMale() {
        // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        XCTAssertEqual(BodyCalculations.bmrMifflinStJeor(weightKg: 80, heightCm: 180, ageYears: 30, profile: .male),
                       1780.0, accuracy: 1e-12)
    }

    func testBmrMifflinFemale() {
        // 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
        XCTAssertEqual(BodyCalculations.bmrMifflinStJeor(weightKg: 60, heightCm: 165, ageYears: 30, profile: .female),
                       1320.25, accuracy: 1e-12)
    }

    func testBmrKatchMcArdle() {
        // 370 + 21.6 * 70 = 370 + 1512 = 1882
        XCTAssertEqual(BodyCalculations.bmrKatchMcArdle(fatFreeMassKg: 70), 1882.0, accuracy: 1e-12)
    }

    // MARK: TDEE

    func testTdeeDefaultPal() {
        XCTAssertEqual(BodyCalculations.tdee(bmr: 1780), 1780 * 1.55, accuracy: 1e-9)
    }

    // MARK: computeDerivedFields

    func testComputeDerivedFieldsPrefersKatchWhenNavyAvailable() {
        let derived = BodyCalculations.computeDerivedFields(
            weightKg: 80, heightCm: 180, ageYears: 30, profile: .male,
            neckCm: 38, waistCm: 88, hipCm: nil)
        XCTAssertNotNil(derived.navyBodyFatPct)
        // BMR comes from Katch-McArdle (uses fat-free mass), not Mifflin
        let expectedKatch = 370.0 + 21.6 * derived.fatFreeMassKg
        XCTAssertEqual(derived.bmr, expectedKatch, accuracy: 1e-9)
    }

    func testComputeDerivedFieldsFallsBackToMifflinWhenNavyMissing() {
        // No neck/waist supplied -> Navy nil -> Mifflin fallback
        let derived = BodyCalculations.computeDerivedFields(
            weightKg: 80, heightCm: 180, ageYears: 30, profile: .male,
            neckCm: nil, waistCm: nil, hipCm: nil)
        XCTAssertNil(derived.navyBodyFatPct)
        XCTAssertEqual(derived.bmr, 1780.0, accuracy: 1e-12)
    }

    func testComputeDerivedFieldsAlwaysReturnsDeurenberg() {
        // Deurenberg is BMI-based — always computable, so the field is non-optional.
        let derived = BodyCalculations.computeDerivedFields(
            weightKg: 80, heightCm: 180, ageYears: 30, profile: .male,
            neckCm: nil, waistCm: nil, hipCm: nil)
        XCTAssertEqual(derived.deurenbergBodyFatPct, 1.20 * derived.bmi + 0.23 * 30 - 10.8 - 5.4, accuracy: 1e-9)
    }

    // MARK: projectWeightTrend

    func testProjectWeightTrendLinearLossExtends() {
        // 4 weekly samples, 1 kg/week loss. Project 4 weeks -> 76.0 kg.
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let week: TimeInterval = 7 * 24 * 3600
        let samples: [StubSample] = [
            StubSample(date: now,                     weightKg: 80.0),
            StubSample(date: now.addingTimeInterval(week),     weightKg: 79.0),
            StubSample(date: now.addingTimeInterval(2 * week), weightKg: 78.0),
            StubSample(date: now.addingTimeInterval(3 * week), weightKg: 77.0)
        ]
        let projected = BodyCalculations.projectWeightTrend(measurements: samples, weeksAhead: 4)
        XCTAssertNotNil(projected)
        // After 4 more weeks at -1 kg/week: 77 - 4 = 73 kg. (last sample was at week 3 = 77 kg)
        XCTAssertEqual(projected!, 73.0, accuracy: 1e-9)
    }

    func testProjectWeightTrendReturnsNilForTooFewSamples() {
        let now = Date()
        let samples: [StubSample] = [
            StubSample(date: now, weightKg: 80),
            StubSample(date: now.addingTimeInterval(7 * 24 * 3600), weightKg: 79)
        ]
        XCTAssertNil(BodyCalculations.projectWeightTrend(measurements: samples, weeksAhead: 4))
    }

    func testProjectWeightTrendReturnsNilForTooShortSpan() {
        // 3 samples, all within an hour — span < 1 day -> nil
        let now = Date()
        let samples: [StubSample] = [
            StubSample(date: now,                          weightKg: 80),
            StubSample(date: now.addingTimeInterval(600),  weightKg: 80),
            StubSample(date: now.addingTimeInterval(1200), weightKg: 80)
        ]
        XCTAssertNil(BodyCalculations.projectWeightTrend(measurements: samples, weeksAhead: 4))
    }

    func testIsTrendUnreliableTrueForHighVariance() {
        let now = Date()
        let week: TimeInterval = 7 * 24 * 3600
        let samples: [StubSample] = [
            StubSample(date: now,                     weightKg: 80),
            StubSample(date: now.addingTimeInterval(week),     weightKg: 75),
            StubSample(date: now.addingTimeInterval(2 * week), weightKg: 85),
            StubSample(date: now.addingTimeInterval(3 * week), weightKg: 78)
        ]
        XCTAssertTrue(BodyCalculations.isTrendUnreliable(measurements: samples))
    }

    // MARK: weeklyWeightDelta

    func testWeeklyDeltaReturnsNilForEmptyMeasurements() {
        XCTAssertNil(BodyCalculations.weeklyWeightDelta(measurements: [] as [StubSample]))
    }

    func testWeeklyDeltaReturnsNilWhenAllMeasurementsWithinSixDays() {
        // All measurements clustered within ~3 days — no >=6-day-old reference exists
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let day: TimeInterval = 24 * 3600
        let samples: [StubSample] = [
            StubSample(date: now,                            weightKg: 78.0),
            StubSample(date: now.addingTimeInterval(-day),    weightKg: 78.5),
            StubSample(date: now.addingTimeInterval(-3 * day), weightKg: 79.0)
        ]
        XCTAssertNil(BodyCalculations.weeklyWeightDelta(measurements: samples))
    }

    func testWeeklyDeltaIsLatestMinusReference() {
        // 80 kg now, 82 kg 7 days ago → delta = -2 kg (loss)
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let week: TimeInterval = 7 * 24 * 3600
        let samples: [StubSample] = [
            StubSample(date: now,                          weightKg: 80.0),
            StubSample(date: now.addingTimeInterval(-week), weightKg: 82.0)
        ]
        XCTAssertEqual(
            BodyCalculations.weeklyWeightDelta(measurements: samples)!,
            -2.0,
            accuracy: 1e-9
        )
    }

    func testWeeklyDeltaPicksMostRecentReferenceAtSixPlusDays() {
        // Mix: latest now, 4d ago (too recent), 8d ago (qualifies, 79kg), 14d ago (older, 81kg)
        // Expected: pick 8d-ago reference (most recent qualifying), delta = 78 - 79 = -1
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let day: TimeInterval = 24 * 3600
        let samples: [StubSample] = [
            StubSample(date: now,                             weightKg: 78.0),
            StubSample(date: now.addingTimeInterval(-4 * day),  weightKg: 78.4),
            StubSample(date: now.addingTimeInterval(-8 * day),  weightKg: 79.0),
            StubSample(date: now.addingTimeInterval(-14 * day), weightKg: 81.0)
        ]
        XCTAssertEqual(
            BodyCalculations.weeklyWeightDelta(measurements: samples)!,
            -1.0,
            accuracy: 1e-9
        )
    }

    /// Subtraktionsrauschen: 70.3 - 70.2 ist in Gleitkomma 0.09999999999999432
    /// und wurde in der Anzeige (`truncated(to: 1)`) zu 0.0 statt 0.1.
    func testWeeklyDeltaIsFreeOfSubtractionNoise() {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let week: TimeInterval = 7 * 24 * 3600
        let samples: [StubSample] = [
            StubSample(date: now,                          weightKg: 70.3),
            StubSample(date: now.addingTimeInterval(-week), weightKg: 70.2)
        ]
        let delta = BodyCalculations.weeklyWeightDelta(measurements: samples)!
        XCTAssertEqual(delta, 0.1, accuracy: 1e-12)
        XCTAssertEqual(delta.truncated(to: 1), 0.1, accuracy: 1e-12)
    }

    func testWeeklyDeltaDisplaysEveryHundredGramStepExactly() {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let week: TimeInterval = 7 * 24 * 3600
        for baseTenths in 500...1500 {
            for deltaTenths in 1...30 {
                let samples: [StubSample] = [
                    StubSample(date: now, weightKg: Double(baseTenths + deltaTenths) / 10.0),
                    StubSample(date: now.addingTimeInterval(-week), weightKg: Double(baseTenths) / 10.0)
                ]
                let delta = BodyCalculations.weeklyWeightDelta(measurements: samples)!
                XCTAssertEqual(
                    delta.truncated(to: 1), Double(deltaTenths) / 10.0, accuracy: 1e-9,
                    "\(Double(baseTenths + deltaTenths) / 10.0) - \(Double(baseTenths) / 10.0)"
                )
            }
        }
    }

    func testIsTrendUnreliableFalseForStableProgression() {
        let now = Date()
        let week: TimeInterval = 7 * 24 * 3600
        let samples: [StubSample] = [
            StubSample(date: now,                     weightKg: 80.0),
            StubSample(date: now.addingTimeInterval(week),     weightKg: 79.5),
            StubSample(date: now.addingTimeInterval(2 * week), weightKg: 79.0),
            StubSample(date: now.addingTimeInterval(3 * week), weightKg: 78.5)
        ]
        XCTAssertFalse(BodyCalculations.isTrendUnreliable(measurements: samples))
    }
}
