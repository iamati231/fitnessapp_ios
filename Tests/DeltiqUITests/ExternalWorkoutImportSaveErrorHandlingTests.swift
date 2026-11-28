import XCTest

/// Audit-Fund (Modul (e), WorkoutSummaryView+Health-Export): `syncExternalWorkouts`
/// nutzte `try? context.save()` am Ende des Imports komplett ohne Fehlerbehandlung -
/// kein catch, kein Log, kein Rueckgabewert. Bei einem Save-Fehlschlag blieben frisch
/// eingefuegte Sessions/Exercises/Logs bis zum naechsten App-Neustart unbemerkt im
/// ModelContext haengen. Quelltext-Pruefung (gleiches Muster wie
/// `ExerciseCardSaveErrorHandlingTests`), weil `context.save()` keinen Test-Seam fuer
/// einen echten Fehlschlag hat.
final class ExternalWorkoutImportSaveErrorHandlingTests: XCTestCase {
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
                contentsOf: sourcesRoot.appendingPathComponent("Workout/ExternalWorkoutImportService.swift"),
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

    func testSyncExternalWorkoutsSignatureReturnsDiscardableBool() throws {
        let code = Self.stripLineComments(try source)
        guard let start = code.range(of: "public static func syncExternalWorkouts(") else {
            return XCTFail("syncExternalWorkouts signature not found")
        }
        guard let end = code.range(of: ") async", range: start.upperBound..<code.endIndex) else {
            return XCTFail("end of syncExternalWorkouts parameter list not found")
        }
        let signatureTail = code[end.upperBound..<code.index(end.upperBound, offsetBy: 20, limitedBy: code.endIndex) ?? code.endIndex]
        XCTAssertTrue(signatureTail.contains("-> Bool"),
                      "syncExternalWorkouts must return Bool so callers can react to a save failure")
        XCTAssertTrue(code.contains("@discardableResult"),
                      "the Bool return must be @discardableResult so existing fire-and-forget callers keep compiling")
    }

    func testSyncExternalWorkoutsCatchesSaveFailureInsteadOfSwallowingIt() throws {
        let code = Self.stripLineComments(try source)
        guard let start = code.range(of: "public static func syncExternalWorkouts(") else {
            return XCTFail("syncExternalWorkouts not found")
        }
        guard let end = code.range(of: "static func insertSession", range: start.upperBound..<code.endIndex) else {
            return XCTFail("end of syncExternalWorkouts body not found")
        }
        let body = code[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("try? context.save()"),
                       "the bare try? save must be replaced with an explicit do/catch")
        XCTAssertTrue(body.contains("try context.save()"),
                      "a real save attempt must still happen")
        XCTAssertTrue(body.contains("catch"),
                      "a failed save must no longer be silently swallowed")
    }
}
