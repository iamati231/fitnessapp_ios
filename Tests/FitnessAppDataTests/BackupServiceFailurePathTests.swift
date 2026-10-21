#if canImport(SwiftData)
import XCTest
@testable import FitnessAppData

/// Settings-Epic Phase 6 (Befund-Nachtrag "Kein-Equipment"... nein — Punkt 6
/// der Vorgabe: "Offene Phase-5-Fehlerpfade testbar machen"). Nutzt die
/// beiden neuen, gezielten DI-Seams:
///   - `SharedStore.health` (`internal(set)` statt `private(set)`)
///   - `BackupService.backupsDirectoryOverride`
/// um BL-03 (echter Ladefehler vs. "keine Sicherungen"), BL-05 (Löschfehler
/// nicht verschluckt) und "fehlgeschlagene Sicherung" (storeUnhealthy) ohne
/// echten App-Group-Fehler bzw. echte Dateisystem-Berechtigungen zu testen.
@available(iOS 17.0, macOS 14.0, *)
final class BackupServiceFailurePathTests: XCTestCase {

    private func makeBundle() -> DataExportBundle {
        DataExportBundle(data: Data("test".utf8), suggestedFilename: "test.zip", totalRows: 0)
    }

    private func withTempBackupsDirectory(_ body: (URL) throws -> Void) rethrows {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupServiceFailurePathTests-\(UUID().uuidString)", isDirectory: true)
        let original = BackupService.backupsDirectoryOverride
        BackupService.backupsDirectoryOverride = dir
        defer {
            BackupService.backupsDirectoryOverride = original
            try? FileManager.default.removeItem(at: dir)
        }
        try body(dir)
    }

    /// "Fehlgeschlagene Sicherung darf Export/Teilen nicht verhindern, aber
    /// der Teilfehler muss sichtbar bleiben" (Phase-5-Vorgabe) — hier wird
    /// direkt verifiziert, dass `BackupService.store` bei eingefrorenem
    /// Alt-Store abbricht, OHNE einen App-Group-Fehler provozieren zu müssen.
    func testStoreThrowsStoreUnhealthyWhenStoreIsFrozen() throws {
        let originalHealth = SharedStore.health
        defer { SharedStore.health = originalHealth }
        SharedStore.health = .fellBackAfterGroupStoreFailure("test-reason")

        try withTempBackupsDirectory { _ in
            XCTAssertThrowsError(try BackupService.store(bundle: makeBundle(), reason: .manual)) { error in
                guard case BackupService.BackupError.storeUnhealthy(let detail) = error else {
                    return XCTFail("Erwartete .storeUnhealthy, bekam \(error)")
                }
                XCTAssertEqual(detail, "test-reason")
            }
        }
    }

    /// Gegenprobe: bei gesundem Store (Normalfall `.ok`) scheitert `store`
    /// NICHT an der Health-Pruefung — sichert ab, dass der neue DI-Seam das
    /// Verhalten im gesunden Fall nicht veraendert.
    func testStoreSucceedsWhenStoreIsHealthy() throws {
        let originalHealth = SharedStore.health
        defer { SharedStore.health = originalHealth }
        SharedStore.health = .ok

        try withTempBackupsDirectory { _ in
            let generation = try BackupService.store(bundle: makeBundle(), reason: .manual)
            XCTAssertTrue(FileManager.default.fileExists(atPath: generation.url.path))
        }
    }

    /// BL-03: ein echter Lesefehler muss sich von "noch nie gesichert" (leere
    /// Liste) unterscheiden lassen. Simuliert ueber einen Pfad, der auf eine
    /// REGULAERE DATEI statt ein Verzeichnis zeigt — `contentsOfDirectory`
    /// wirft dann einen echten I/O-Fehler, unabhaengig von Unix-Permissions
    /// (die in einer Sandbox/als Root oft gar nicht greifen).
    func testListGenerationsDistinguishesEmptyFromRealLoadError() throws {
        try withTempBackupsDirectory { _ in
            // Fall 1: echtes "noch nie gesichert" -> leeres Array, kein Fehler.
            XCTAssertEqual(try BackupService.listGenerations(), [])
        }

        let fileNotDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupServiceFailurePathTests-file-\(UUID().uuidString)")
        try Data().write(to: fileNotDirectory)
        defer { try? FileManager.default.removeItem(at: fileNotDirectory) }

        let original = BackupService.backupsDirectoryOverride
        BackupService.backupsDirectoryOverride = fileNotDirectory
        defer { BackupService.backupsDirectoryOverride = original }

        // Fall 2: echter Lesefehler -> muss werfen, NICHT leise [] liefern.
        XCTAssertThrowsError(try BackupService.listGenerations())
    }

    /// BL-05: Löschfehler dürfen nicht verschluckt werden. `delete` zeigt auf
    /// eine nicht-existente Datei — ein echter, umgebungsunabhängiger Fehler.
    func testDeletePropagatesRealIOErrorInsteadOfSwallowing() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupServiceFailurePathTests-missing-\(UUID().uuidString).zip")
        let generation = BackupService.Generation(
            url: missing, createdAt: Date(), byteCount: 0, rowCount: 0, reason: .manual
        )
        XCTAssertThrowsError(try BackupService.delete(generation))
    }
}
#endif
