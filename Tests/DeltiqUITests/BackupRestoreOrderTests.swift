import XCTest

/// Modul-6-Audit: `BackupListView.restore()` rief `BackupService.createBackupAsync(
/// reason: .preImport)` bisher VOR dem Lesen der Ziel-Generation auf.
/// `createBackupAsync` rotiert intern auf `BackupService.maxGenerations` (siehe
/// `BackupServiceFailurePathTests.testStoringANewGenerationAtRotationLimitDeletesTheOldestFile`,
/// das den Mechanismus direkt an `BackupService` belegt) — bei Rotation am
/// Limit UND Restore der aeltesten Generation loeschte die frisch angelegte
/// `preImport`-Sicherung die Ziel-Datei, BEVOR `Data(contentsOf:)` sie lesen
/// konnte. `restore()` ist eine `private` SwiftUI-Methode ohne Test-Seam fuer
/// einen echten Restore-Durchlauf, daher Quelltext-Pruefung der Reihenfolge
/// (gleiches Muster wie `GearEditorPersistenceTests`/`BodyDataEditorRollbackTests`).
final class BackupRestoreOrderTests: XCTestCase {
    private var source: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // this file
                .deletingLastPathComponent() // DeltiqUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/DeltiqUI/Settings/BackupListView.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    func testRestoreReadsTheTargetGenerationBeforeCreatingThePreImportBackup() throws {
        let source = try source
        guard let restoreStart = source.range(of: "private func restore(_ generation: BackupService.Generation) {") else {
            return XCTFail("restore(_:) not found at the expected signature")
        }
        guard let readLine = source.range(
            of: "let data = try await Task.detached { try Data(contentsOf: generation.url) }.value",
            range: restoreStart.upperBound..<source.endIndex
        ) else {
            return XCTFail("the target-generation read line was not found inside restore(_:)")
        }
        guard let preImportLine = source.range(
            of: "try await BackupService.createBackupAsync(context: ctx, reason: .preImport)",
            range: restoreStart.upperBound..<source.endIndex
        ) else {
            return XCTFail("the preImport backup line was not found inside restore(_:)")
        }

        XCTAssertTrue(
            readLine.upperBound <= preImportLine.lowerBound,
            "restore() must read the target generation's bytes BEFORE creating the preImport safety backup - "
                + "otherwise that backup's own rotation can delete the very file being restored "
                + "(reproducible at BackupService.maxGenerations)"
        )
    }

    func testRestoreReloadsTheListAfterAFailure() throws {
        let source = try source
        guard let restoreStart = source.range(of: "private func restore(_ generation: BackupService.Generation) {") else {
            return XCTFail("restore(_:) not found at the expected signature")
        }
        guard let catchStart = source.range(of: "} catch {", range: restoreStart.upperBound..<source.endIndex) else {
            return XCTFail("restore()'s catch block was not found")
        }
        guard let catchEnd = source.range(of: "\n            }", range: catchStart.upperBound..<source.endIndex) else {
            return XCTFail("restore()'s catch block end was not found")
        }
        let catchBody = source[catchStart.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(
            catchBody.contains("self.reload()"),
            "a failed restore must reload the generation list, otherwise it can keep showing an " +
                "already-rotated-away generation and a retry repeats the same failure"
        )
    }
}
