import XCTest

/// Modul-6-Audit: `DataImportService.runImport` wandte `settings.csv`
/// (UserDefaults-Schreiben ueber `SettingsPortability.apply`, sofort und
/// ungepuffert) bisher als Tick Nr. 2 von 16 an — lange BEVOR das einzige
/// `context.save()` lief, das laut eigenem Kommentar "Wipe und Merge atomisch
/// committet". Schlug irgendetwas DANACH fehl (allen voran `context.save()`
/// selbst), blieb der SwiftData-Teil unveraendert auf dem alten Stand, waehrend
/// die App-Einstellungen (Einheiten, Erinnerungen, Theme) bereits dauerhaft auf
/// den Backup-Stand umgeschrieben waren — ein inkonsistenter Mischzustand.
///
/// `runImport` ist `@MainActor private static` ohne DI-Seam fuer einen echten
/// `ModelContext.save()`-Fehlschlag (gleiches Problem wie bei den SwiftUI-
/// Editoren, siehe `BodyDataEditorRollbackTests`), daher Quelltext-Pruefung der
/// Reihenfolge statt eines echten Fehlschlag-Tests.
final class DataImportSettingsAtomicityTests: XCTestCase {
    private var source: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // this file
                .deletingLastPathComponent() // DeltiqDataTests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/DeltiqData/Export/DataImportService.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    func testSettingsImportRunsAfterContextSaveNotBeforeIt() throws {
        let source = try source
        // Die praezise, zeilenverankerte Suche (statt eines blossen
        // Substring-Matches) ist noetig, weil der Doc-Kommentar direkt
        // darueber den Ausdruck selbst in Backticks als Prosa erwaehnt
        // ("...das fruehere `try context.save()` direkt...") - ein
        // einfacher `range(of: "try context.save()")` faende faelschlich
        // diese Kommentarzeile statt der echten Anweisung.
        guard let saveLine = source.range(of: "\n        try context.save()\n") else {
            return XCTFail("the context.save() call was not found as a standalone statement")
        }
        guard let settingsTickLine = source.range(of: "try await tick(\"settings.csv\") {") else {
            return XCTFail("the settings.csv tick was not found")
        }
        XCTAssertTrue(
            saveLine.upperBound <= settingsTickLine.lowerBound,
            "settings.csv must be applied to UserDefaults AFTER context.save() succeeds, not before it - "
                + "otherwise a later failure (chiefly context.save() itself) leaves UserDefaults already "
                + "overwritten with the backup's values while the SwiftData side stays on the old state"
        )
    }
}
