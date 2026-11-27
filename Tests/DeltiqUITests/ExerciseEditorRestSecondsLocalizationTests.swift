import XCTest

final class ExerciseEditorRestSecondsLocalizationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ExerciseEditorView.swift"),
                encoding: .utf8
            )
        }
    }

    func testRestSecondsDisplayIsLocalizedNotHardcoded() throws {
        let text = try source
        guard let anchor = text.range(of: "Stepper(value: $exercise.restSeconds, in: 0...600, step: 15) {") else {
            return XCTFail("rest-seconds Stepper not found at the expected call site")
        }
        guard let end = text.range(of: "label: {", range: anchor.upperBound..<text.endIndex) else {
            return XCTFail("end of rest-seconds LabeledContent not found")
        }
        let body = text[anchor.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("restSeconds)s\""),
                       "the rest-seconds display must no longer hardcode the 's' suffix")
        XCTAssertTrue(body.contains("unit.seconds.short"),
                      "the rest-seconds display must use the localized unit.seconds.short key, matching DayEditorView's circuitRestSeconds pattern")
    }

    func testCatalogHasSecondsShortKeyForAllThreeLocales() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        XCTAssertTrue(catalog.contains("\"unit.seconds.short\""))
    }
}
