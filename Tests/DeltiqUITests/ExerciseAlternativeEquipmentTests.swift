import XCTest

/// Regression guard: jede Eintraege in ExerciseLibraryData.alternatives muss
/// ein Ziel-Exercise haben, dessen equipmentRequirement mit der Ziel-Umgebung
/// kompatibel ist. Verhindert erneute "Plan schrumpft durch pullUpBar-
/// Scheinlösung im homeGym"-Bugs.
final class ExerciseAlternativeEquipmentTests: XCTestCase {

    private func readSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Sources/DeltiqCore/Programs/ExerciseLibraryData.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Kein homeGym-Eintrag in der alternatives-Tabelle darf auf eine Uebung
    /// zeigen, die equipmentRequirement: .item(.pullUpBar) (oder aehnliches
    /// spezialitem) traegt. Erkennbar im Quelltext durch .item(. als Anfang
    /// des equipmentRequirement-Werts im Katalog.
    func testNoHomeGymAlternativeRequiresPullUpBar() throws {
        let source = try readSource()

        // Extrahiere alle homeGym-Werte aus der alternatives-Tabelle.
        // Pattern: .homeGym: "Name" in der Tabelle.
        let pattern = #"\.homeGym:\s+"([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = source as NSString
        var homeGymAlternatives: [String] = []
        for match in regex.matches(in: source, range: NSRange(location: 0, length: ns.length)) {
            if match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: source) {
                homeGymAlternatives.append(String(source[r]))
            }
        }

        // Exercises mit pullUpBar-Requirement (inkl. Türrahmen/Fußfixierung-Proxies)
        let pullUpBarExercises: Set<String> = [
            "Klimmzüge (weit)",
            "Klimmzüge (eng/Chin-up)",
            "Klimmzüge",
            "Australian Pull-ups",
            "Handtuch-Rudern (Türrahmen)",
            "Dips (Brust)",
            "Dips (Trizeps)",
            "Nordic Curls",
        ]

        var failures: [String] = []
        for name in homeGymAlternatives {
            if pullUpBarExercises.contains(name) {
                failures.append("'\(name)' als homeGym-Alternative benoetigt pullUpBar — kein Standard-homeGym-Item")
            }
        }
        XCTAssertTrue(failures.isEmpty, "Ungueltiger homeGym-Alternative:\n" + failures.joined(separator: "\n"))
    }

    /// Spiegelbild fuer noEquipment: kein Eintrag darf auf pullUpBar-Exercises zeigen
    /// (wird schon von isCompatible abgefangen, aber explizit als Regressionsschutz).
    func testNoNoEquipmentAlternativeRequiresPullUpBar() throws {
        let source = try readSource()

        let pattern = #"\.noEquipment:\s+"([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = source as NSString
        var alternatives: [String] = []
        for match in regex.matches(in: source, range: NSRange(location: 0, length: ns.length)) {
            if match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: source) {
                alternatives.append(String(source[r]))
            }
        }

        let pullUpBarExercises: Set<String> = [
            "Klimmzüge (weit)",
            "Klimmzüge (eng/Chin-up)",
            "Klimmzüge",
            "Australian Pull-ups",
            "Handtuch-Rudern (Türrahmen)",
            "Dips (Brust)",
            "Dips (Trizeps)",
            "Nordic Curls",
        ]

        var failures: [String] = []
        for name in alternatives {
            if pullUpBarExercises.contains(name) {
                failures.append("'\(name)' als noEquipment-Alternative benoetigt pullUpBar")
            }
        }
        XCTAssertTrue(failures.isEmpty, "Ungueltiger noEquipment-Alternative:\n" + failures.joined(separator: "\n"))
    }
}
