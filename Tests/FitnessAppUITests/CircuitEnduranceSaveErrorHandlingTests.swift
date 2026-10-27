import XCTest

/// Audit-Fund (ponytail-audit UI, Save-Fehler in Live-Workouts): dieselbe Bug-Klasse
/// wie `TimedWorkoutPlayerSaveErrorHandlingTests`, hier fuer `CircuitWorkoutPlayerView.swift`
/// (5 Checkpoints) und `EnduranceIntervalPlayerView.swift` (5 Checkpoints). Beide rufen
/// die geteilten `finishTimedSession`/`discardTimedSession` aus `TimedWorkoutPlayerView.swift`
/// auf - deren eigene Korrektheit ist dort separat getestet, hier nur, dass beide Dateien
/// den `Bool`-Rueckgabewert auswerten und keinen `try?`/`modelContext.rollback()` mehr haben.
final class CircuitEnduranceSaveErrorHandlingTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func source(_ file: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent("Workout/\(file)"), encoding: .utf8)
    }

    private func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testCircuitPlayerHasNoTryQuestionMarkSaveAndFiveDoCatchCheckpoints() throws {
        let text = try source("CircuitWorkoutPlayerView.swift")
        XCTAssertFalse(text.contains("try? modelContext.save()"))
        XCTAssertFalse(stripLineComments(text).contains("modelContext.rollback()"))
        // 5 audit-named checkpoints: finishPreroll, toggleExerciseChecked,
        // completeCurrentRound, beginRest, endRest.
        XCTAssertEqual(text.components(separatedBy: "} catch {").count - 1, 5)
        XCTAssertTrue(text.contains("if !discardTimedSession(session, modelContext: modelContext, dismiss: dismiss) {"))
        XCTAssertTrue(text.contains("if !finishTimedSession("))
    }

    func testEndurancePlayerHasNoTryQuestionMarkSaveAndFiveDoCatchCheckpoints() throws {
        let text = try source("EnduranceIntervalPlayerView.swift")
        XCTAssertFalse(text.contains("try? modelContext.save()"))
        XCTAssertFalse(stripLineComments(text).contains("modelContext.rollback()"))
        // 5 audit-named checkpoints: finishPreroll, beginPhase, advancePhase(.work),
        // pausePhase, resumePhase.
        XCTAssertEqual(text.components(separatedBy: "} catch {").count - 1, 5)
        XCTAssertTrue(text.contains("if !discardTimedSession(session, modelContext: modelContext, dismiss: dismiss) {"))
        XCTAssertTrue(text.contains("if !finishTimedSession("))
    }
}
