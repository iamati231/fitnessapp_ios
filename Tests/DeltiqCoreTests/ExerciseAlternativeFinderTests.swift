import XCTest
@testable import DeltiqCore

/// UI-Ticket ("Plan Bauen Schritt 3: Template-Layout und Übungsalternativen").
final class ExerciseAlternativeFinderTests: XCTestCase {

    // MARK: - alternatives(for:equipmentPool:maxExperience:)

    func testAlternativesExcludesTheOriginalExerciseItself() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Bankdrücken", equipmentPool: [.barbell, .dumbbell, .machine], maxExperience: .advanced
        )
        XCTAssertFalse(result.contains { $0.name == "Bankdrücken" })
    }

    func testAlternativesOnlyIncludesTheSameMuscleGroup() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Bankdrücken",
            equipmentPool: [.barbell, .dumbbell, .machine, .bodyweight, .cable, .kettlebell],
            maxExperience: .advanced
        )
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.primaryMuscle == .chest })
    }

    func testAlternativesOnlyIncludesEquipmentFromTheGivenPool() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Bankdrücken", equipmentPool: [.dumbbell], maxExperience: .advanced
        )
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.equipment == .dumbbell })
        XCTAssertTrue(result.contains { $0.name == "Bankdrücken (KH)" })
    }

    func testAlternativesRespectsTheMaximumExperienceLevel() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Plank", equipmentPool: [.bodyweight], maxExperience: .beginner
        )
        XCTAssertTrue(result.contains { $0.name == "Crunches (BW)" })
        XCTAssertFalse(
            result.contains { $0.name == "Dragon Flag" },
            "Dragon Flag ist .advanced, darf bei maxExperience .beginner nicht erscheinen"
        )
    }

    func testAlternativesReturnsEmptyForACardioExercise() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Easy Run", equipmentPool: [.bodyweight], maxExperience: .advanced
        )
        XCTAssertTrue(result.isEmpty, "Cardio-Uebungen duerfen keine Kraft-Alternativen vorschlagen (Trainingsart bleibt gewahrt)")
    }

    func testAlternativesReturnsEmptyForAnUnknownExerciseName() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Ganz Erfundene Testuebung", equipmentPool: [.barbell, .dumbbell], maxExperience: .advanced
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testAlternativesRespectsTheLimit() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Bankdrücken",
            equipmentPool: [.barbell, .dumbbell, .machine, .bodyweight, .cable, .kettlebell],
            maxExperience: .advanced,
            limit: 2
        )
        XCTAssertLessThanOrEqual(result.count, 2)
    }

    // MARK: - adjustedSpec(replacing:with:)

    func testAdjustedSpecKeepsOriginalVolumeWhenTimeBasedMatches() {
        let original = ExerciseSpec(name: "Bankdrücken", sets: 4, repsMin: 6, repsMax: 8, restSeconds: 120)
        let target = ExerciseLibraryData.byName["Bankdrücken (KH)"]!

        let adjusted = ExerciseAlternativeFinder.adjustedSpec(replacing: original, with: target)

        XCTAssertEqual(adjusted.name, "Bankdrücken (KH)")
        XCTAssertEqual(adjusted.sets, 4)
        XCTAssertEqual(adjusted.repsMin, 6)
        XCTAssertEqual(adjusted.repsMax, 8)
        XCTAssertEqual(adjusted.restSeconds, 120)
    }

    /// UI-Ticket Punkt 3: Wiederholungen der Original-Uebung duerfen nicht
    /// blind als Sekunden fuer eine neu zeitbasierte Ersatz-Uebung
    /// uebernommen werden.
    func testAdjustedSpecResetsRepsRangeWhenSwitchingFromRepsToTimeBased() {
        let original = ExerciseSpec(name: "Crunches (BW)", sets: 3, repsMin: 15, repsMax: 20, restSeconds: 60)
        let target = ExerciseLibraryData.byName["Plank"]!

        let adjusted = ExerciseAlternativeFinder.adjustedSpec(replacing: original, with: target)

        XCTAssertEqual(adjusted.name, "Plank")
        XCTAssertNotEqual(adjusted.repsMin, 15, "15-20 Wiederholungen duerfen nicht als 15-20 Sekunden Haltezeit uebernommen werden")
        XCTAssertEqual(adjusted.sets, 3, "Saetze bleiben unabhaengig vom Uebungstyp gueltig")
        XCTAssertEqual(adjusted.restSeconds, 60, "Pause bleibt unabhaengig vom Uebungstyp gueltig")
    }

    func testAdjustedSpecResetsSecondsRangeWhenSwitchingFromTimeBasedToReps() {
        let original = ExerciseSpec(name: "Plank", sets: 3, repsMin: 45, repsMax: 45, restSeconds: 60)
        let target = ExerciseLibraryData.byName["Crunches (BW)"]!

        let adjusted = ExerciseAlternativeFinder.adjustedSpec(replacing: original, with: target)

        XCTAssertEqual(adjusted.name, "Crunches (BW)")
        XCTAssertNotEqual(adjusted.repsMax, 45, "45 Sekunden Haltezeit duerfen nicht als 45 Wiederholungen uebernommen werden")
    }

    func testAdjustedSpecPreservesSetsAndRestEvenAcrossATypeChange() {
        let original = ExerciseSpec(name: "Crunches (BW)", sets: 4, repsMin: 12, repsMax: 15, restSeconds: 75)
        let target = ExerciseLibraryData.byName["Plank"]!

        let adjusted = ExerciseAlternativeFinder.adjustedSpec(replacing: original, with: target)

        XCTAssertEqual(adjusted.sets, 4)
        XCTAssertEqual(adjusted.restSeconds, 75)
    }

    // MARK: - Issue #51 Punkt 2: baselineSubstitute — Ersatz-Schwierigkeit am tatsaechlichen Niveau

    /// "Breite Liegestütze": explizites `baselineMinBand: .low`, Default-
    /// Schwierigkeit `.intermediate`. Fuer einen push:.veryLow-Nutzer (ein
    /// echter TEST-Befund, kein uebersprungener Test) durfte der Ersatz
    /// VORHER bis zur ORIGINAL-Schwierigkeit (.intermediate) reichen — das
    /// sagt nichts ueber das tatsaechliche Leistungsniveau dieses Nutzers
    /// aus. Jetzt muss er auf das Band-abgeleitete Maximum (.beginner)
    /// begrenzt sein.
    func testBaselineSubstituteCapsReplacementDifficultyByActualBandNotOriginalDifficulty() {
        let veryLowPush = BaselineBands(push: .veryLow, legs: .moderate, pull: .moderate,
                                        core: .moderate, cardio: .unknown)
        let blocked = ExerciseSpec(name: "Breite Liegestütze", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 60)
        let result = ExerciseAlternativeFinder.baselineSubstitute(blocked, bands: veryLowPush, equipmentPool: [.bodyweight])
        guard let substitute = result, let spec = ExerciseLibraryData.byName[substitute.name] else {
            return XCTFail("Expected an accessible .beginner chest substitute for a veryLow push band")
        }
        XCTAssertEqual(spec.difficultyLevel, .beginner,
            "Substitute for a veryLow-banded user must be capped at .beginner, not merely at the original's .intermediate difficultyLevel")
    }

    /// Gegenprobe: fuer einen high-gebandeten Nutzer darf derselbe Mechanismus
    /// nicht unnoetig einschraenken — "Breite Liegestütze" selbst ist ja schon
    /// zugaenglich (high erfuellt .low), die Funktion gibt sie unveraendert zurueck.
    func testBaselineSubstituteDifficultyCapDoesNotAffectAlreadyAccessibleExercises() {
        let highPush = BaselineBands(push: .high, legs: .high, pull: .high, core: .high, cardio: .high)
        let spec = ExerciseSpec(name: "Breite Liegestütze", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 60)
        let result = ExerciseAlternativeFinder.baselineSubstitute(spec, bands: highPush, equipmentPool: [.bodyweight])
        XCTAssertEqual(result?.name, "Breite Liegestütze", "Already-accessible exercises must pass through unchanged")
    }

    // MARK: - Audit-Fund: nil equipmentRequirement darf im strict-bodyweight-
    // und im profile-Pfad von findAccessibleAlternative nicht automatisch
    // als "keine Anforderung" durchgehen (ExerciseTemplateSpec.swift: "nil =
    // noch nicht erfasst — KEIN Hinweis auf 'keine Voraussetzung'").
    // `findAccessibleAlternative` ist `private` und ueber den oeffentlichen
    // `baselineSubstitute`-Pfad wegen der `.first`-Katalog-Reihenfolge nicht
    // zuverlaessig isoliert testbar (mehrere unannotierte Bodyweight-
    // Uebungen derselben Muskelgruppe stehen im Katalog VOR den hier
    // zitierten Beispielen) - deshalb Source-Inspection, analog zum
    // etablierten Muster fuer private Implementierungsdetails in dieser
    // Codebase.
    private var alternativeFinderSource: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqCore/Programs/ExerciseAlternativeFinder.swift"),
                encoding: .utf8
            )
        }
    }

    func testFindAccessibleAlternativeDoesNotTreatNilEquipmentRequirementAsNoRequirement() throws {
        let source = try alternativeFinderSource
        guard let start = source.range(of: "private static func findAccessibleAlternative("),
              let end = source.range(of: "\n    }", range: start.upperBound..<source.endIndex)
        else {
            return XCTFail("findAccessibleAlternative not found")
        }
        let body = source[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains(".requiresNoPhysicalItem) ?? true"),
            "strict-bodyweight check must not default an unannotated (nil) equipmentRequirement to 'needs no equipment'")
        XCTAssertFalse(body.contains("equipmentRequirement == nil\n                    || $0.equipmentRequirement!.evaluate"),
            "profile check must not let an unannotated (nil) equipmentRequirement bypass the actual evaluation")
    }

    /// Konkrete Katalog-Faelle, die den Fund ausgeloest haben (beide
    /// `equipment: .bodyweight` klassifiziert, brauchen de facto ein
    /// physisches Geraet, `equipmentRequirement` bislang nicht annotiert) -
    /// Regressionsschutz, falls diese Eintraege kuenftig doch annotiert
    /// werden sollten, ohne die Source-Inspection anzupassen.
    func testKnownUnannotatedBodyweightEntriesActuallyNeedEquipment() {
        for name in ["Medizinball-Slam", "Battle Ropes"] {
            guard let spec = ExerciseLibraryData.byName[name] else {
                XCTFail("\(name) missing from catalog")
                continue
            }
            XCTAssertEqual(spec.equipment, .bodyweight)
            XCTAssertNil(spec.equipmentRequirement,
                "\(name) muesste bereits annotiert sein, falls dieser Test fehlschlaegt - Fix ggf. nicht mehr noetig")
        }
    }

    /// "Long Run" ist `isCardio: true`, `primaryMuscle: .core` (Notbehelf-
    /// Platzhalter), ohne explizites `difficultyLevel` also `.intermediate`
    /// -> `effectiveBaselineMinBand == .low`. Ein `core: .veryLow`-Band
    /// erfuellt `.low` nicht - vor dem Fix wurde dadurch eine unpassende
    /// Core-Kraftuebung als Ersatz fuer einen Lauf vorgeschlagen.
    func testBaselineSubstituteNeverReplacesACardioExerciseEvenWhenItsCoreBandIsGated() {
        let veryLowCore = BaselineBands(push: .high, legs: .high, pull: .high, core: .veryLow, cardio: .high)
        let longRun = ExerciseSpec(name: "Long Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, isCardio: true)
        let result = ExerciseAlternativeFinder.baselineSubstitute(longRun, bands: veryLowCore, equipmentPool: [.bodyweight])
        XCTAssertEqual(result?.name, "Long Run", "Cardio exercises must never be routed through the muscle-based baseline substitution")
    }
}
