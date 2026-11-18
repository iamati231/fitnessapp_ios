import XCTest

/// Parity guard: stellt sicher, dass (a) jeder im Swift-Code referenzierte
/// Lokalisierungs-Key in Localizable.xcstrings vorhanden ist und (b) jeder
/// Katalog-Key die Sprachen DE, EN und TR abgedeckt hat.
///
/// Warum #filePath statt Bundle: swift test kopiert Localizable.xcstrings nur
/// roh in den Test-Bundle, ohne den Xcode-Compile-Schritt — String(localized:)
/// gibt dann den rohen Key zurueck (dokumentiert in FoodCatalogLocalizationTests).
/// Deshalb direkte Datei-IO via #filePath-relativer Navigation.
final class LocalizationCatalogParityTests: XCTestCase {

    private func catalogStrings() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(root["strings"] as? [String: Any])
    }

    private func swiftFiles(inDirectory subpath: String) -> [URL] {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent(subpath)
        guard let e = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Alle Text("key", bundle:), String(localized: "key", bundle:) und
    /// LocalizedStringKey("key") Referenzen im DeltiqUI-Quellbaum.
    private func keysUsedInSource() throws -> [(key: String, file: String)] {
        let files = swiftFiles(inDirectory: "Sources/DeltiqUI")
        var found: [(key: String, file: String)] = []

        let patterns = [
            #"String\s*\(\s*localized:\s*"([\w.]+)""#,
            #"Text\s*\(\s*"([\w.]+)"\s*,\s*bundle:"#,
            #"LocalizedStringKey\s*\(\s*"([\w.]+)"\s*\)"#,
            #"String\s*\(\s*localized:\s*"([\w.]+)"\s*\)"#,
        ]
        let regexes = patterns.compactMap { try? NSRegularExpression(pattern: $0) }

        for file in files {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let ns = source as NSString
            let range = NSRange(location: 0, length: ns.length)
            for regex in regexes {
                for match in regex.matches(in: source, range: range) {
                    if match.numberOfRanges > 1,
                       let r = Range(match.range(at: 1), in: source) {
                        found.append((key: String(source[r]), file: file.lastPathComponent))
                    }
                }
            }
        }
        return found
    }

    // MARK: - Tests

    func testAllSourceKeysExistInCatalog() throws {
        let catalog = try catalogStrings()
        let usedKeys = try keysUsedInSource()

        var failures: [String] = []
        var seen = Set<String>()
        for (key, file) in usedKeys {
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if catalog[key] == nil {
                failures.append("'\(key)' (referenziert in \(file)) fehlt in Localizable.xcstrings")
            }
        }
        XCTAssertTrue(failures.isEmpty, "Fehlende Catalog-Keys:\n" + failures.joined(separator: "\n"))
    }

    func testAllCatalogKeysHaveDeEnTrTranslations() throws {
        let catalog = try catalogStrings()

        var failures: [String] = []
        for (key, value) in catalog {
            guard let entry = value as? [String: Any] else { continue }
            // shouldTranslate: false bedeutet explizit kein Uebersetzungsbedarf
            if (entry["shouldTranslate"] as? Bool) == false { continue }
            let locs = entry["localizations"] as? [String: Any] ?? [:]
            for lang in ["de", "en", "tr"] {
                if locs[lang] == nil {
                    failures.append("'\(key)' fehlt \(lang.uppercased())-Uebersetzung")
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, "Unvollstaendige Uebersetzungen:\n" + failures.joined(separator: "\n"))
    }
}
