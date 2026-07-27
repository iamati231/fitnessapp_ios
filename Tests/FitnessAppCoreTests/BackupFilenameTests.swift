import XCTest
@testable import FitnessAppCore

/// DEL-227: Das Namensschema traegt Zeitstempel und Ausloeser jeder
/// Backup-Generation. Ein Parse-Fehler laesst bestehende Backups aus der
/// Wiederherstellungs-Liste verschwinden — genau dann, wenn der User sie
/// braucht.
final class BackupFilenameTests: XCTestCase {

    private let reference = Date(timeIntervalSince1970: 1_770_000_000)

    // MARK: Roundtrip

    func testRoundTripPreservesReasonAndTimestamp() throws {
        for reason in BackupFilename.Reason.allCases {
            let name = BackupFilename.make(reason: reason, at: reference)
            // XCTUnwrap statt Optional-Chaining: die accuracy-Ueberladung von
            // XCTAssertEqual nimmt kein Optional, und ein `?? 0` wuerde einen
            // fehlgeschlagenen Parse als "Zeitstempel 1970" durchlassen statt
            // den Test klar scheitern zu lassen.
            let parsed = try XCTUnwrap(
                BackupFilename.parse(name),
                "\(name) liess sich nicht zurueckparsen"
            )
            XCTAssertEqual(parsed.reason, reason, "Reason \(reason) ging verloren")
            // Sekunden-Granularitaet: der Stempel traegt keine
            // Sub-Sekunden-Anteile.
            XCTAssertEqual(
                parsed.date.timeIntervalSince1970,
                reference.timeIntervalSince1970,
                accuracy: 1.0
            )
        }
    }

    func testFilenameShape() {
        let name = BackupFilename.make(reason: .automatic, at: reference)
        XCTAssertTrue(name.hasPrefix("deltiq-backup_automatic_"))
        XCTAssertTrue(name.hasSuffix(".zip"))
        // Kein Doppelpunkt, kein Slash, kein Leerzeichen — muss ein
        // gueltiger Dateiname auf jedem Dateisystem sein.
        XCTAssertFalse(name.contains(":"))
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(" "))
    }

    /// Der Stempel muss in UTC gebildet werden, sonst kollidieren zwei
    /// Backups nach einem Zeitzonen-Wechsel oder sortieren falsch.
    func testTimestampIsUTC() {
        // 2026-02-02T03:20:00Z
        let known = Date(timeIntervalSince1970: 1_770_002_400)
        let name = BackupFilename.make(reason: .manual, at: known)
        XCTAssertTrue(name.contains("20260202-032000"), "erwartet UTC-Stempel, war: \(name)")
    }

    // MARK: Sortierbarkeit

    /// Zwei Backups derselben Sekunde ergeben denselben Namen — die spaetere
    /// Generation ueberschreibt die fruehere. Das ist gewollt (kein
    /// Datenverlust, weil beide denselben Stand haetten), muss aber bewusst
    /// so bleiben.
    func testSameSecondProducesSameName() {
        XCTAssertEqual(
            BackupFilename.make(reason: .automatic, at: reference),
            BackupFilename.make(reason: .automatic, at: reference)
        )
    }

    /// Lexikografische Sortierung der Namen muss der chronologischen
    /// entsprechen — die Restore-Liste verlaesst sich darauf.
    func testNamesSortChronologically() {
        let early = BackupFilename.make(reason: .automatic, at: Date(timeIntervalSince1970: 1_700_000_000))
        let late = BackupFilename.make(reason: .automatic, at: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertLessThan(early, late)
    }

    // MARK: Fremde Dateien

    func testForeignFilenamesAreRejected() {
        let foreign = [
            "irgendwas.zip",
            "deltiq-backup.zip",
            "deltiq-backup_automatic.zip",          // Zeitstempel fehlt
            "deltiq-backup_unknownreason_20260202-032000.zip",
            "deltiq-backup_automatic_kaputt.zip",   // Stempel unparsebar
            "deltiq-backup_automatic_20260202-032000.txt",
            "deltiq-export_automatic_20260202-032000.zip",
            "",
        ]
        for name in foreign {
            XCTAssertNil(BackupFilename.parse(name), "\"\(name)\" haette abgelehnt werden muessen")
        }
    }

    /// Der manuelle Export heisst anders und darf nicht als Generation
    /// auftauchen — sonst wuerde die Rotation fremde Dateien loeschen.
    func testManualExportFilenameIsNotAGeneration() {
        XCTAssertNil(BackupFilename.parse("deltiq-export-2026-02-02.zip"))
    }
}
