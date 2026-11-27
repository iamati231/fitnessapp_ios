import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor): der Auf-/Zuklapp-
/// Button von `warmupRampSection(_:)` baute sein Label als rohes `HStack` aus
/// zwei `Image(systemName:)` (flame, chevron.up/down) + `Text`, ohne jede
/// Accessibility-Annotation - VoiceOver las beide Icon-Namen zusaetzlich vor,
/// und der erweitert/eingeklappt-Zustand war ausschliesslich ueber die
/// Chevron-Richtung visuell codiert. Quelltext-Pruefung (kein ViewInspector/
/// XCUITest-Harness vorhanden), folgt dem etablierten Source-Inspection-Muster
/// (siehe `ExerciseCardSaveErrorHandlingTests`).
final class ExerciseCardWarmupRampAccessibilityTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private var source: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("Workout/ExerciseCard.swift"),
                encoding: .utf8
            )
        }
    }

    private var catalog: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("Resources/Localizable.xcstrings"),
                encoding: .utf8
            )
        }
    }

    private func warmupRampSectionBody() throws -> Substring {
        let text = try source
        guard let start = text.range(of: "private func warmupRampSection(_ ramp: [WarmupStep]) -> some View {") else {
            XCTFail("warmupRampSection(_:) not found at the expected signature")
            return text[text.startIndex..<text.startIndex]
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            XCTFail("end of warmupRampSection(_:) not found")
            return text[text.startIndex..<text.startIndex]
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testToggleButtonGroupsChildrenAndHidesDecorativeIcons() throws {
        let body = try warmupRampSectionBody()
        XCTAssertTrue(body.contains(".accessibilityElement(children: .ignore)"),
                      "the toggle button must group its icon+text children into one VoiceOver stop")
    }

    func testToggleButtonSpeaksExpandedCollapsedState() throws {
        let body = try warmupRampSectionBody()
        XCTAssertTrue(body.contains(".accessibilityValue(Text(rampExpanded ? \"warmup.ramp.expanded\" : \"warmup.ramp.collapsed\""),
                      "the expanded/collapsed state must be spoken via accessibilityValue, not only via chevron direction")
    }

    func testCatalogHasExpandedAndCollapsedKeys() throws {
        let catalog = try catalog
        XCTAssertTrue(catalog.contains("\"warmup.ramp.expanded\""))
        XCTAssertTrue(catalog.contains("\"warmup.ramp.collapsed\""))
        XCTAssertTrue(catalog.contains("\"ausgeklappt\""))
        XCTAssertTrue(catalog.contains("\"eingeklappt\""))
    }
}
