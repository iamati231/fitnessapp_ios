import XCTest

/// Modul-9-Audit (Dashboard): `apply()` mutierte `Exercise.suggestedWeight` in
/// der Schleife VOR `context.save()`, ohne Rollback bei Fehlschlag. Alle drei
/// Call-Sites (`DashboardView`, `FourWeekReviewView`, `DayEditorView`) nutzen
/// bewusst `try?` — der Call-Site-Kommentar geht davon aus, ein Fehlschlag
/// zeige "unveraenderte Gewichte". Ohne Rollback stimmte das nicht: die
/// Mutation blieb live im ModelContext und konnte durch einen spaeteren,
/// unabhaengigen Autosave trotzdem landen — dann sogar ohne den schuetzenden
/// `lastAppliedKey`-Zeitstempel (Doppelreduktion beim naechsten Start).
/// Quelltext-Pruefung, weil `save()` keinen Test-Seam fuer einen echten
/// Fehlschlag hat (gleiches Muster wie `DeloadManagerSaveErrorHandlingTests`).
final class AbsenceDeloadSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqData/AbsenceDeload.swift"),
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

    private static func body(of signature: String, in cleaned: String) throws -> Substring {
        guard let funcStart = cleaned.range(of: signature) else {
            throw XCTSkip("\(signature) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            throw XCTSkip("end of \(signature) not found")
        }
        return cleaned[funcStart.upperBound..<funcEnd.lowerBound]
    }

    func testApplyRollsBackOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "public static func apply(", in: cleaned)

        guard let tryRange = body.range(of: "try context.save()") else {
            return XCTFail("must call context.save() via do/catch")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found — a failed save must not leave reduced weights live")
        }
        guard let catchEnd = body.range(of: "\n            throw error", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block must re-throw so the caller's try? sees a nil result")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("suggestedWeight = change.original"),
                      "rollback must restore the pre-reduction weight")

        // `defaults.set(lastAppliedKey, ...)` darf nur NACH einem erfolgreichen
        // Save passieren — sonst greift der Doppelanwendungs-Schutz nie.
        guard let setAppliedRange = body.range(of: "defaults.set(now.timeIntervalSince1970, forKey: lastAppliedKey)", range: catchEnd.upperBound..<body.endIndex) else {
            return XCTFail("lastAppliedKey must still be set on the success path")
        }
        XCTAssertTrue(setAppliedRange.lowerBound > catchEnd.upperBound,
                     "lastAppliedKey must only be set AFTER the catch block, i.e. only on a successful save")
    }

    /// Alle drei Call-Sites nutzen `try?` — das ist jetzt sicher, weil
    /// `apply()` selbst bei Fehlschlag keine Mutation ueberleben laesst.
    /// Dieser Test haelt fest, welche Caller sich auf dieses Verhalten
    /// verlassen, damit ein kuenftiger Umbau sie nicht uebersieht.
    func testKnownCallSitesStillExist() throws {
        for (file, relativePath) in [
            ("DashboardView.swift", "Sources/DeltiqUI/DashboardView.swift"),
            ("FourWeekReviewView.swift", "Sources/DeltiqUI/FourWeekReviewView.swift"),
            ("DayEditorView.swift", "Sources/DeltiqUI/Workout/DayEditorView.swift"),
        ] {
            let callerSource = try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent(relativePath),
                encoding: .utf8
            )
            XCTAssertTrue(callerSource.contains("try? AbsenceDeload.apply(in: modelContext, factor: factor)"),
                          "\(file) no longer calls AbsenceDeload.apply as expected — re-check this test's coverage")
        }
    }
}
