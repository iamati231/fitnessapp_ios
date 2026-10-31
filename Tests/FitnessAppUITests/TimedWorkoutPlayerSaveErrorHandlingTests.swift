import XCTest

/// Audit-Fund (ponytail-audit UI, Save-Fehler in Live-Workouts): `finishTimedSession`/
/// `discardTimedSession` (geteilt von AMRAP/EMOM/ForTime/Circuit/Endurance) sowie die
/// sechs AMRAP/EMOM/ForTime-eigenen Checkpoint-Saves nutzten `try? modelContext.save()`.
/// Quelltext-Pruefung (gleiches Muster wie `BodyDataEditorRollbackTests`), weil `save()`
/// keinen Test-Seam fuer einen echten Fehlschlag hat. Sucht auf kommentarbereinigtem
/// Text (siehe `WorkoutSummaryViewSaveErrorHandlingTests` fuer die Begruendung).
final class TimedWorkoutPlayerSaveErrorHandlingTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private var source: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("Workout/TimedWorkoutPlayerView.swift"),
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

    func testNoTryQuestionMarkSaveRemains() throws {
        XCTAssertFalse(try source.contains("try? modelContext.save()"))
    }

    func testNoBlanketContextRollbackIntroduced() throws {
        XCTAssertFalse(Self.stripLineComments(try source).contains("modelContext.rollback()"))
    }

    /// `finishTimedSession` muss bei einem Save-Fehler `false` zurueckgeben, BEVOR
    /// zur Summary navigiert wird - sonst zeigt die UI einen Abschluss, der nie
    /// gespeichert wurde.
    func testFinishTimedSessionReturnsFalseBeforeNavigatingToSummary() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "func finishTimedSession(") else {
            return XCTFail("finishTimedSession not found")
        }
        guard let catchReturn = cleaned.range(of: "} catch {\n        return false\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("finishTimedSession must catch a failed save and return false")
        }
        guard let navigateCall = cleaned.range(of: "navigation.workoutPath.append(SummaryRoute(session: session))", range: catchReturn.upperBound..<cleaned.endIndex) else {
            return XCTFail("navigation.workoutPath.append(SummaryRoute(...)) not found after the catch block")
        }
        XCTAssertTrue(navigateCall.lowerBound > catchReturn.upperBound,
                      "navigation must only happen AFTER the catch block, i.e. only on a successful save")
    }

    /// `discardTimedSession`: analoges Muster - kein `dismiss()` bei fehlgeschlagenem Save.
    func testDiscardTimedSessionReturnsFalseBeforeDismissing() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "func discardTimedSession(") else {
            return XCTFail("discardTimedSession not found")
        }
        guard let catchReturn = cleaned.range(of: "} catch {\n        return false\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("discardTimedSession must catch a failed save and return false")
        }
        guard let dismissCall = cleaned.range(of: "dismiss()\n    return true", range: catchReturn.upperBound..<cleaned.endIndex) else {
            return XCTFail("dismiss() + return true not found after the catch block")
        }
        XCTAssertTrue(dismissCall.lowerBound > catchReturn.upperBound,
                      "dismiss() must only happen AFTER the catch block, i.e. only on a successful save")
    }

    /// Alle fuenf Call-Sites (AMRAP/EMOM/ForTime/Circuit/Endurance) muessen den
    /// `Bool`-Rueckgabewert jetzt auswerten statt ihn zu ignorieren.
    func testAllFiveFinishTimedSessionCallersCheckTheReturnValue() throws {
        var total = 0
        for file in ["TimedWorkoutPlayerView.swift", "CircuitWorkoutPlayerView.swift", "EnduranceIntervalPlayerView.swift"] {
            let text = try String(contentsOf: sourcesRoot.appendingPathComponent("Workout/\(file)"), encoding: .utf8)
            total += text.components(separatedBy: "if !finishTimedSession(").count - 1
        }
        XCTAssertEqual(total, 5, "expected 5 finishTimedSession call sites (AMRAP/EMOM/ForTime/Circuit/Endurance), each gating on the Bool")
    }

    func testAllFiveDiscardTimedSessionCallersCheckTheReturnValue() throws {
        var total = 0
        for file in ["TimedWorkoutPlayerView.swift", "CircuitWorkoutPlayerView.swift", "EnduranceIntervalPlayerView.swift"] {
            let text = try String(contentsOf: sourcesRoot.appendingPathComponent("Workout/\(file)"), encoding: .utf8)
            total += text.components(separatedBy: "if !discardTimedSession(").count - 1
        }
        XCTAssertEqual(total, 5, "expected 5 discardTimedSession call sites (AMRAP/EMOM/ForTime/Circuit/Endurance), each gating on the Bool")
    }

    /// Zaehlt die Gesamtzahl der umgestellten do/catch-Bloecke in dieser Datei:
    /// 6 AMRAP/EMOM/ForTime-eigene Checkpoints (je finishPreroll() + ein zweiter
    /// Fortschritts-Save) + die 2 geteilten Funktionen oben.
    func testEightDoCatchBlocksTotalInThisFile() throws {
        let occurrences = try source.components(separatedBy: "} catch {").count - 1
        XCTAssertEqual(occurrences, 8, "6 player-specific checkpoints + finishTimedSession + discardTimedSession")
    }
}
