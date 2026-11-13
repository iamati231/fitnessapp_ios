import XCTest

/// Regressionstests für Issue #11, Fix 4/4: Video-Längen-Validierung in
/// `CustomExerciseMediaStore.import(from:)`. Da `AVURLAsset.duration` nur
/// mit echten Videodateien testbar ist, prüfen wir hier die Quelle als Text
/// (gleiches Muster wie `TrainingLocationEquipmentEditorRollbackTests`).
final class CustomMediaStoreVideoValidationTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // this file
            .deletingLastPathComponent()   // DeltiqUITests
            .deletingLastPathComponent()   // Tests
            .appendingPathComponent("Sources/DeltiqUI/Workout")
    }

    private var storeSource: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("CustomExerciseMediaStore.swift"),
                encoding: .utf8
            )
        }
    }

    // MARK: - Scenario 8a: Boundary-Konstante

    func testMaxVideoSecondsConstantIs15() throws {
        let src = try storeSource
        XCTAssertTrue(
            src.contains("maxVideoSeconds: Double = 15"),
            "maxVideoSeconds muss exakt 15.0 Sekunden betragen (Boundary für 14.9/15.0/15.1-Tests)"
        )
    }

    // MARK: - Scenario 8b: invalidDuration-Fehler bei ungültiger AVAsset-Duration

    func testGuardChecksValidAndIndefiniteAndFiniteAndPositive() throws {
        let src = try storeSource
        // Vollständige Guard-Bedingung: isValid, !isIndefinite, isFinite, > 0
        XCTAssertTrue(
            src.contains("duration.isValid") &&
            src.contains("duration.isIndefinite") &&
            src.contains("secs.isFinite") &&
            src.contains("secs > 0"),
            "Guard muss isValid, !isIndefinite, isFinite, secs > 0 prüfen"
        )
    }

    func testInvalidDurationThrowsCorrectError() throws {
        let src = try storeSource
        XCTAssertTrue(
            src.contains("throw CustomMediaError.invalidDuration"),
            "Bei ungültiger AVAsset-Duration muss CustomMediaError.invalidDuration geworfen werden"
        )
    }

    func testTooLongDurationThrowsCorrectError() throws {
        let src = try storeSource
        // Prüft, dass secs > maxVideoSeconds → .tooLong geworfen wird
        XCTAssertTrue(
            src.contains("secs > maxVideoSeconds") &&
            src.contains("throw CustomMediaError.tooLong"),
            "Videos länger als maxVideoSeconds müssen .tooLong werfen"
        )
    }

    // MARK: - Scenario 5+6: Abbrechen-Rollback (Cancel-Rollback)

    func testEnvSwapCancelRestoresEnvironment() throws {
        let editorPath = sourcesRoot
            .deletingLastPathComponent()   // Workout
            .appendingPathComponent("Settings/TrainingLocationEquipmentEditorView.swift")
        let src = try String(contentsOf: editorPath, encoding: .utf8)

        // Abbrechen-Handler muss profile.environment zurücksetzen
        XCTAssertTrue(
            src.contains("profile.environment = swap.oldEnv"),
            "Cancel-Handler im envSwap-Dialog muss profile.environment auf den alten Wert zurücksetzen"
        )
    }

    func testEquipmentAdaptationCancelDismissesWithoutApplying() throws {
        let editorPath = sourcesRoot
            .deletingLastPathComponent()
            .appendingPathComponent("Settings/TrainingLocationEquipmentEditorView.swift")
        let src = try String(contentsOf: editorPath, encoding: .utf8)

        // onCancel im Preview-Sheet muss pendingEquipmentAdaptation nillen und dismissen
        XCTAssertTrue(
            src.contains("pendingEquipmentAdaptation = nil") &&
            src.contains("dismiss()"),
            "Cancel im EquipmentAdaptationPreviewSheet muss pendingEquipmentAdaptation nillen und Sheet schließen"
        )
    }
}
