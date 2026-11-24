import XCTest

/// Modul-14-Audit (Analytics/DataImport). `DataImportService.ImportError`
/// (DeltiqData, kein Resource-Bundle) hatte hartcodierte deutsche
/// `errorDescription`-Texte, die ueber `error.localizedDescription` direkt in
/// drei UI-Screens landeten (DataImportView, BackupListView, OnboardingView)
/// — EN/TR-Nutzer sahen bei einem defekten Import-Archiv deutschen Text
/// statt einer Uebersetzung. Fix: der Service liefert nur noch einen
/// englischen Fallback (analog `CSVReadError.errorDescription`), die
/// eigentliche Lokalisierung passiert ueber die neue
/// `Error.localizedImportMessage`-Extension in DeltiqUI (DataImportView.swift),
/// die alle drei Call-Sites jetzt statt `.localizedDescription` nutzen.
final class DataImportErrorLocalizationTests: XCTestCase {

    private func fileContents(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Wie `PRHistoryViewLocalizationTests.stripLineComments` — verhindert,
    /// dass ein erklaerender Kommentar einen `.contains`-Check faelschlich
    /// bestehen oder scheitern laesst (Modul-11-Pitfall).
    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testImportErrorNoLongerHardcodesGerman() throws {
        let source = Self.stripLineComments(try fileContents("Sources/DeltiqData/Export/DataImportService.swift"))
        XCTAssertFalse(source.contains("Archiv konnte nicht gelesen werden"),
                       "zipNotReadable must not hardcode German anymore")
        XCTAssertFalse(source.contains("Archiv enthält kein meta.json"),
                       "missingMeta must not hardcode German anymore")
        XCTAssertFalse(source.contains("wird von dieser App-Version nicht unterstützt"),
                       "unsupportedFormatVersion must not hardcode German anymore")
    }

    func testDataImportViewDefinesLocalizedImportMessage() throws {
        let source = Self.stripLineComments(try fileContents("Sources/DeltiqUI/Settings/DataImportView.swift"))
        XCTAssertTrue(source.contains("var localizedImportMessage: String"))
        for key in [
            "settings.dataImport.error.zipNotReadable",
            "settings.dataImport.error.missingMeta",
            "settings.dataImport.error.unsupportedFormatVersion",
        ] {
            XCTAssertTrue(source.contains("String(localized: \"\(key)\", bundle: .module)"),
                          "missing localized mapping for \(key)")
        }
    }

    func testAllThreeImportCallSitesUseLocalizedImportMessage() throws {
        let dataImportView = Self.stripLineComments(try fileContents("Sources/DeltiqUI/Settings/DataImportView.swift"))
        let backupListView = Self.stripLineComments(try fileContents("Sources/DeltiqUI/Settings/BackupListView.swift"))
        let onboardingView = Self.stripLineComments(try fileContents("Sources/DeltiqUI/OnboardingView.swift"))

        XCTAssertTrue(dataImportView.contains("self.errorMessage = error.localizedImportMessage"),
                      "DataImportView's performImport catch must use localizedImportMessage")
        XCTAssertTrue(backupListView.contains("self.errorMessage = error.localizedImportMessage"),
                      "BackupListView's performImport catch must use localizedImportMessage")
        XCTAssertTrue(onboardingView.contains("backupImportError = error.localizedImportMessage"),
                      "OnboardingView's performImport catch must use localizedImportMessage")
    }
}
