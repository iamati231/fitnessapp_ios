import XCTest

/// Audit-Fund (Modul 22, ExerciseEditorView): `progressionSection`s
/// "Compound-Lift"-Toggle band `exercise.isCompound` direkt, ohne wie der
/// gleichwertige Toggle in `customMetadataSection` per `syncCustomTemplate`
/// das zugehoerige `ExerciseTemplate.isSystemCompound` zurueckzuspiegeln
/// (DEL-163/AC2) - bei gleichzeitig sichtbarer Smart-Progression + Custom-
/// Metadaten-Section driftete der Template-Wert vom Instanz-Wert weg.
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe PlanBuilderPreSeededFlowPinnedTests).
final class ExerciseEditorCompoundToggleTemplateSyncTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ExerciseEditorView.swift"),
                encoding: .utf8
            )
        }
    }

    func testProgressionSectionCompoundToggleUsesSharedBindingNotRawExerciseProperty() throws {
        let text = try source
        guard let start = text.range(of: "private var progressionSection: some View {") else {
            return XCTFail("progressionSection not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of progressionSection not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        XCTAssertFalse(body.contains("Toggle(isOn: $exercise.isCompound)"),
                       "the Compound-Lift toggle must no longer bind exercise.isCompound directly - it skips the custom-template sync")
        XCTAssertTrue(body.contains("Toggle(isOn: compoundBinding)"),
                      "the Compound-Lift toggle must use the shared compoundBinding so it synchronizes the custom template like customMetadataSection's toggle")
    }

    func testCompoundBindingSetterSyncsCustomTemplate() throws {
        let text = try source
        guard let start = text.range(of: "private var compoundBinding: Binding<Bool> {") else {
            return XCTFail("compoundBinding not found - the shared binding must exist")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of compoundBinding not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        XCTAssertTrue(body.contains("exercise.isCompound = newValue"))
        XCTAssertTrue(body.contains("syncCustomTemplate { $0.isSystemCompound = newValue }"),
                      "compoundBinding's setter must mirror the change onto the custom ExerciseTemplate, matching customMetadataSection's prior behavior")
    }
}
