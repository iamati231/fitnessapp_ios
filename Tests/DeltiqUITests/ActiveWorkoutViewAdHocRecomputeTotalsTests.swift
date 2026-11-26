import XCTest

/// Audit-Fund (Modul 19, aktives Training). `deleteAdHocExercise` ruft nach
/// dem Entfernen einer Ad-Hoc-Uebung explizit `session.recomputeTotals(
/// exerciseCount:)` auf, damit `session.exerciseCount` nicht veraltet.
/// `addAdHocExercise`/`addAdHocCustomExercise` fuegten dagegen eine neue
/// Uebung ein, ohne denselben Aufruf zu machen - `exerciseCount` blieb bis
/// `finishWorkout()` zu niedrig.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class ActiveWorkoutViewAdHocRecomputeTotalsTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ActiveWorkoutView.swift"),
                encoding: .utf8
            )
        }
    }

    private func body(ofFunctionStartingWith signature: String, in text: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            XCTFail("\(signature) not found at the expected signature")
            return ""
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            XCTFail("end of \(signature) not found")
            return ""
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testAddAdHocExerciseRecomputesExerciseCount() throws {
        let text = try source
        let addBody = try body(ofFunctionStartingWith: "private func addAdHocExercise(from template: ExerciseTemplate) {", in: text)
        XCTAssertTrue(addBody.contains("session.recomputeTotals(exerciseCount:"),
                      "addAdHocExercise must recompute session.exerciseCount after inserting, matching deleteAdHocExercise")
    }

    func testAddAdHocCustomExerciseRecomputesExerciseCount() throws {
        let text = try source
        let addBody = try body(ofFunctionStartingWith: "private func addAdHocCustomExercise(_ draft: CustomExerciseDraft) {", in: text)
        XCTAssertTrue(addBody.contains("session.recomputeTotals(exerciseCount:"),
                      "addAdHocCustomExercise must recompute session.exerciseCount after inserting, matching deleteAdHocExercise")
    }
}
