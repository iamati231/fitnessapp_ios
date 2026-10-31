import XCTest

/// Audit-Fund (dritter Follow-up-UI-Audit, Fund 6): `isBarbellExercise` war
/// byte-identisch in `SetRow.swift` und `ExerciseCard.swift` dupliziert.
/// Jetzt `Exercise.isBarbellExercise` (FitnessAppData) als einzige Quelle -
/// dieser Test haelt fest, dass keine der beiden Dateien die Kopie wieder
/// einfuehrt.
final class IsBarbellExerciseDedupTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
    }

    func testExerciseHasTheSharedIsBarbellExerciseProperty() throws {
        let text = try String(
            contentsOf: sourcesRoot.appendingPathComponent("FitnessAppData/Exercise.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("public var isBarbellExercise: Bool {"),
                      "Exercise must expose the shared isBarbellExercise computed property")
    }

    func testNeitherUIFileRedefinesIsBarbellExercise() throws {
        let files = [
            "FitnessAppUI/Workout/SetRow.swift",
            "FitnessAppUI/Workout/ExerciseCard.swift",
        ]
        for file in files {
            let text = try String(contentsOf: sourcesRoot.appendingPathComponent(file), encoding: .utf8)
            XCTAssertFalse(text.contains("var isBarbellExercise: Bool {"),
                           "\(file) must reuse Exercise.isBarbellExercise instead of its own copy")
            XCTAssertTrue(text.contains("exercise.isBarbellExercise"),
                          "\(file) must actually call exercise.isBarbellExercise somewhere")
        }
    }
}
