import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor): `addSet()` hatte keine
/// Obergrenze fuer `exercise.sets`, obwohl der Schwester-Codepfad `ExerciseEditorView`
/// dasselbe Feld ueber `Stepper(value: $exercise.sets, in: 1...20)` auf 20 deckelt.
/// Quelltext-Pruefung (gleiches Muster wie `ExerciseCardSaveErrorHandlingTests`), weil
/// kein ViewInspector/XCUITest-Harness vorhanden ist.
final class ExerciseCardAddSetUpperBoundTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private var source: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("Workout/ExerciseCard.swift"),
                encoding: .utf8
            )
        }
    }

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    private func editorStepperUpperBound() throws -> String {
        try String(
            contentsOf: sourcesRoot.appendingPathComponent("Workout/ExerciseEditorView.swift"),
            encoding: .utf8
        )
    }

    func testAddSetHasAnUpperBoundGuardMatchingTheEditorsTwentyCap() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func addSet() {") else {
            return XCTFail("addSet() not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("addSet's end was not found")
        }
        let body = cleaned[funcStart.upperBound..<funcEnd.lowerBound]

        XCTAssertTrue(body.contains("guard exercise.sets < 20 else { return }"),
                      "addSet() must refuse to increment exercise.sets once it reaches the editor's 20-cap")

        // Guard must run BEFORE the increment, otherwise sets can still reach 21.
        guard let guardRange = body.range(of: "guard exercise.sets < 20 else { return }"),
              let incrementRange = body.range(of: "exercise.sets += 1") else {
            return XCTFail("expected both the guard and the increment in addSet()")
        }
        XCTAssertTrue(guardRange.upperBound < incrementRange.lowerBound,
                      "the upper-bound guard must run before exercise.sets += 1")
    }

    func testEditorsCapRemainsTwentySoTheTwoLimitsStayInSync() throws {
        XCTAssertTrue(try editorStepperUpperBound().contains("Stepper(value: $exercise.sets, in: 1...20)"),
                      "this test's 20-cap assumption is pinned against ExerciseEditorView's own Stepper range")
    }
}
