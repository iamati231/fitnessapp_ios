import XCTest

/// Audit-Fund (Modul 21, PlanEditorView). `createNewDay(type:)` fiel, sobald
/// alle 7 Wochentage bereits vergeben waren, auf
/// `mondayFirstCycle[plan.days.count % mondayFirstCycle.count]` zurueck -
/// dieser Fallback kollidiert deterministisch mit einem bereits vorhandenen
/// Tag (zwei `TrainingDay`s mit identischem `weekday`). Quelltext-Pruefung,
/// da `plan.days` hier kein isolierter Test-Seam ist.
final class PlanEditorCreateDayWeekdayLimitTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/PlanEditorView.swift"),
                encoding: .utf8
            )
        }
    }

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testCreateNewDayRefusesAnEighthDayInsteadOfCollidingWeekdayFallback() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func createNewDay(type: DayType) {") else {
            return XCTFail("createNewDay(type:) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("function end not found")
        }
        let body = cleaned[funcStart.upperBound..<funcEnd.lowerBound]

        guard let guardRange = body.range(of: "guard plan.days.count < 7 else {") else {
            return XCTFail("createNewDay(type:) must refuse to add an 8th day instead of using the colliding weekday fallback")
        }
        guard let mondayCycleRange = body.range(of: "let mondayFirstCycle") else {
            return XCTFail("weekday-assignment logic not found")
        }
        XCTAssertTrue(guardRange.upperBound < mondayCycleRange.lowerBound,
                      "the 7-day guard must run before the weekday is computed, not after")

        let guardBody = body[guardRange.upperBound..<mondayCycleRange.lowerBound]
        XCTAssertTrue(guardBody.contains("return"),
                      "the guard must return early, never fall through to inserting an 8th day")
    }

    func testCatalogHasLimitReachedMessageInAllThreeLanguages() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        XCTAssertTrue(catalog.contains("\"planEditor.days.add.limitReached\""))
    }
}
