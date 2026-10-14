#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Settings-Epic Phase 2 (docs/SETTINGS_UX_AUDIT.md, Befund PE-FFM): deckt
/// den neuen `makeWeightOnly`-Service und den `BodyMeasurementMigrator`-
/// Backfill ab, der bereits gespeicherte, aus dem BMI-Naeherungsfallback
/// erfundene KFA/FFM/FFMI-Werte bereinigt.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class BodyMeasurementTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - makeWeightOnly

    func testMakeWeightOnlyComputesBmiAndBmrButNoBodyComposition() {
        let measurement = BodyMeasurement.makeWeightOnly(
            ageYears: 30, weightKg: 80, heightCm: 180, profile: .male
        )
        XCTAssertEqual(measurement.weightKg, 80)
        XCTAssertNotNil(measurement.bmi, "BMI braucht nur Gewicht+Groesse, keine Umfaenge — keine Fabrikation")
        XCTAssertNotNil(measurement.bmr, "BMR braucht nur Gewicht+Groesse+Alter, keine Umfaenge — keine Fabrikation")

        XCTAssertNil(measurement.navyBodyFatPct)
        XCTAssertNil(measurement.deurenbergBodyFatPct,
                     "Der BMI-Naeherungsfallback darf bei makeWeightOnly nie laufen — genau das war der PE-FFM-Bug")
        XCTAssertNil(measurement.selectedBodyFatPct)
        XCTAssertNil(measurement.fatFreeMassKg)
        XCTAssertNil(measurement.ffmi)
        XCTAssertNil(measurement.normalizedFfmi)

        XCTAssertNil(measurement.neckCm)
        XCTAssertNil(measurement.waistCm)
        XCTAssertNil(measurement.hipCm)
    }

    func testMakeWeightOnlyHandlesMissingHeightGracefully() {
        let measurement = BodyMeasurement.makeWeightOnly(
            ageYears: 30, weightKg: 80, heightCm: 0, profile: .female
        )
        XCTAssertNil(measurement.bmi)
        XCTAssertNil(measurement.bmr)
    }

    // MARK: - BodyMeasurementMigrator

    /// Reproduziert exakt den Alt-Bug: `makeDerived` ganz ohne Umfaenge
    /// (wie es `OnboardingView` vor der Umstellung auf `makeWeightOnly` tat)
    /// erfindet KFA/FFM/FFMI ueber den Deurenberg-BMI-Fallback.
    private func legacyFabricatedRow() -> BodyMeasurement {
        BodyMeasurement.makeDerived(ageYears: 30, weightKg: 80, heightCm: 180, profile: .male)
    }

    func testBackfillNullsOnlyRowsWhereDeurenbergFallbackWasUsed() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let fabricated = legacyFabricatedRow()
        XCTAssertNotNil(fabricated.deurenbergBodyFatPct, "Testvoraussetzung: der Alt-Bug reproduziert sich wie erwartet")
        XCTAssertNotNil(fabricated.ffmi, "Testvoraussetzung: FFMI wurde aus dem Fallback abgeleitet")
        context.insert(fabricated)

        let realMeasurement = BodyMeasurement.makeDerived(
            ageYears: 30, weightKg: 80, heightCm: 180, profile: .male,
            neckCm: 38, waistCm: 85
        )
        XCTAssertNotNil(realMeasurement.navyBodyFatPct, "Testvoraussetzung: echte Umfaenge ergeben einen Navy-Wert")
        context.insert(realMeasurement)

        let alreadyWeightOnly = BodyMeasurement.makeWeightOnly(
            ageYears: 30, weightKg: 80, heightCm: 180, profile: .male
        )
        context.insert(alreadyWeightOnly)

        try context.save()

        let updated = BodyMeasurementMigrator.backfillFabricatedBodyCompositionIfNeeded(in: context)
        XCTAssertEqual(updated, 1, "Nur die eine Alt-Zeile ohne Umfaenge braucht Bereinigung")

        XCTAssertNil(fabricated.deurenbergBodyFatPct)
        XCTAssertNil(fabricated.fatFreeMassKg)
        XCTAssertNil(fabricated.ffmi)
        XCTAssertNil(fabricated.normalizedFfmi)
        XCTAssertNotNil(fabricated.bmi, "BMI ist keine Fabrikation und bleibt stehen")
        XCTAssertNotNil(fabricated.bmr, "BMR ist keine Fabrikation und bleibt stehen")
        XCTAssertEqual(fabricated.weightKg, 80, "Das Gewicht selbst wird nie angefasst")

        XCTAssertNotNil(realMeasurement.navyBodyFatPct, "Echte Navy-Messung bleibt unberuehrt")
        XCTAssertNotNil(realMeasurement.deurenbergBodyFatPct, "Der (ungenutzte) Deurenberg-Nebenwert bei echten Umfaengen wird nicht angefasst")
        XCTAssertNotNil(realMeasurement.ffmi)

        XCTAssertNil(alreadyWeightOnly.deurenbergBodyFatPct, "War schon korrekt nil, bleibt unveraendert")
    }

    func testBackfillIsIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(legacyFabricatedRow())
        try context.save()

        let firstPass = BodyMeasurementMigrator.backfillFabricatedBodyCompositionIfNeeded(in: context)
        XCTAssertEqual(firstPass, 1)

        let secondPass = BodyMeasurementMigrator.backfillFabricatedBodyCompositionIfNeeded(in: context)
        XCTAssertEqual(secondPass, 0, "Nach dem Nullen matcht die Zeile das Predicate nicht mehr erneut")
    }

    func testBackfillIsANoOpWhenNoMeasurementsExist() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        XCTAssertEqual(BodyMeasurementMigrator.backfillFabricatedBodyCompositionIfNeeded(in: context), 0)
    }
}
#endif
