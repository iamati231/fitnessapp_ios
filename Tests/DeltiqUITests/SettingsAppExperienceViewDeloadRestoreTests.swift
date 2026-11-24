import XCTest

/// Audit-Fund (Modul 11, Settings): `restoreDeloadWeights()` nutzte
/// `try?`, das den Fehler verschluckte, den `DeloadManager.endDeload` seit
/// PR #88 bei einem Save-Fehlschlag korrekt wirft (inkl. eigenem
/// Rollback) — der Nutzer tippte "Jetzt beenden" und sah bei einem
/// Fehlschlag keinerlei Rueckmeldung. Quelltext-Pruefung, weil `save()`
/// keinen Test-Seam fuer einen echten Fehlschlag hat.
final class SettingsAppExperienceViewDeloadRestoreTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Settings/SettingsAppExperienceView.swift"),
                encoding: .utf8
            )
        }
    }

    func testRestoreDeloadWeightsUsesDoCatchAndSurfacesFailure() throws {
        let text = try source
        guard let start = text.range(of: "private func restoreDeloadWeights() {") else {
            return XCTFail("restoreDeloadWeights() not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of restoreDeloadWeights() not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("try? DeloadManager.endDeload"),
                        "must not silently swallow the error DeloadManager.endDeload now throws")
        XCTAssertTrue(body.contains("try DeloadManager.endDeload"))
        XCTAssertTrue(body.contains("} catch {"))
        XCTAssertTrue(body.contains("deloadRestoreFailed = true"))
        XCTAssertTrue(body.contains("deloadRestoreFailed = false"))
    }
}
