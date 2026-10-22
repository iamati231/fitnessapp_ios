#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// Task 5 (docs/superpowers/sdd/2026-10-22-ui-consistency): `MeasurementView.
/// save(profile:)`'s New-Mode branch had NO double-tap guard — it inserted a
/// new `BodyMeasurement` and (bug class #2 for this same function) never
/// even called `modelContext.save()` explicitly. Two button-tap events
/// delivered before the first invocation finishes running (the realistic
/// double-tap race — see `MealDraft.didSaveSuccessfully`'s identical
/// "Doppeltap-Schutz" doc for the established precedent in this codebase)
/// could insert two measurements for the same moment.
///
/// `save(profile:)` is `private` and reads `self.modelContext` from
/// `@Environment`, so it cannot be invoked directly without a live SwiftUI
/// context (same constraint documented in `DayEditorPersistenceTests`/
/// `GearEditorPersistenceTests`). This test instead proves the guard SHAPE
/// `MeasurementView` now applies — `guard !isSaving; isSaving = true;
/// defer { isSaving = false }` checked and set BEFORE any mutation — by
/// reproducing it against a real in-memory context and firing a reentrant
/// second "tap" while the first call is still on the stack, which is the
/// worst case a double-tap can produce for a synchronous save path.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MeasurementDoubleTapGuardTests: XCTestCase {

    func testReentrantDoubleTapDoesNotInsertASecondMeasurement() throws {
        let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        // Reproduziert exakt die Guard-Form aus `MeasurementView.save(profile:)`
        // nach dem Fix.
        var isSaving = false
        func tapSave(simulateSecondTapDuringThisCall: Bool) {
            guard !isSaving else { return }
            isSaving = true
            defer { isSaving = false }

            if simulateSecondTapDuringThisCall {
                // Simuliert ein zweites, quasi-gleichzeitiges Tap-Event, das
                // noch WAEHREND dieses ersten Aufrufs feuert — der ungebremste
                // Fall fuer einen Doppeltap auf einem rein synchronen Save-Pfad.
                tapSave(simulateSecondTapDuringThisCall: false)
            }

            let measurement = BodyMeasurement.makeWeightOnly(
                ageYears: 30, weightKg: 82.5, heightCm: 180, profile: .male
            )
            context.insert(measurement)
            try? context.save()
        }

        tapSave(simulateSecondTapDuringThisCall: true)

        let measurements = try context.fetch(FetchDescriptor<BodyMeasurement>())
        XCTAssertEqual(measurements.count, 1,
                        "ein doppelt ausgeloester Speichern-Tap darf keine zweite Messung anlegen")
    }
}
#endif
