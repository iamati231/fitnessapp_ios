import XCTest

/// Modul-7-Audit: `ExerciseLibraryView.deleteTemplate(_:)` fetchte und loeschte
/// bisher explizit auch alle `PersonalRecordEntry`-Zeilen mit passender
/// `exerciseTemplateID`, bevor das Template selbst geloescht wurde - das
/// widerspricht direkt der in `ExerciseTemplate.id` dokumentierten harten
/// Anforderung ("Loeschen einer Vorlage darf niemals Logs/PRs mitloeschen")
/// und dem Lösch-Bestaetigungsdialog, der "Bereits geloggte Trainings bleiben
/// erhalten" verspricht. `deleteTemplate` ist eine `private` SwiftUI-Methode
/// ohne Test-Seam (kein `@testable import DeltiqUI`-Zugriff auf private
/// Members, keine UI-Test-Infrastruktur in diesem Projekt), daher
/// Quelltext-Pruefung — gleiches Muster wie `GearEditorPersistenceTests`/
/// `BodyDataEditorRollbackTests`.
final class ExerciseLibraryDeleteTemplateTests: XCTestCase {
    private func source() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI/Settings/ExerciseLibraryView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testDeleteTemplateNeverFetchesOrDeletesPersonalRecordEntries() throws {
        let source = try source()
        guard let start = source.range(of: "private func deleteTemplate(_ template: ExerciseTemplate) {") else {
            return XCTFail("deleteTemplate(_:) not found at the expected signature")
        }
        guard let end = source.range(of: "\n    }", range: start.upperBound..<source.endIndex) else {
            return XCTFail("deleteTemplate(_:)'s closing brace was not found")
        }
        let body = source[start.upperBound..<end.lowerBound]
        XCTAssertFalse(
            body.contains("PersonalRecordEntry"),
            "deleteTemplate must never fetch or delete PersonalRecordEntry rows - a custom exercise's PR/trophy "
                + "history must survive its template's deletion, exactly as the delete-confirmation dialog promises"
        )
        XCTAssertFalse(
            body.contains("modelContext.delete($0)"),
            "deleting PR entries in a loop is the specific pattern that caused the data loss - must not reappear"
        )
    }
}
