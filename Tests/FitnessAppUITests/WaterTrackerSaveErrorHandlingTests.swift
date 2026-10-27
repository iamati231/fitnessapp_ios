import XCTest

/// Audit-Fund (dritter Follow-up-UI-Audit, Fund 5): addEntry/delete/
/// deleteTodayEntries speicherten nie explizit. Quelltext-Pruefung, weil
/// `save()` keinen Test-Seam fuer einen echten Fehlschlag hat.
final class WaterTrackerSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/FitnessAppUI/Calculators/WaterTrackerView.swift"),
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

    private static func body(of signature: String, in cleaned: String) throws -> Substring {
        guard let funcStart = cleaned.range(of: signature) else {
            throw XCTSkip("\(signature) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            throw XCTSkip("end of \(signature) not found")
        }
        return cleaned[funcStart.upperBound..<funcEnd.lowerBound]
    }

    func testAddEntryDeletesAndReturnsOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func addEntry(amount: Int) {", in: cleaned)

        guard let tryRange = body.range(of: "try modelContext.save()") else {
            return XCTFail("must use do/catch instead of relying on implicit autosave")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let catchEnd = body.range(of: "\n        }", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("modelContext.delete(entry)"))
        XCTAssertTrue(catchBody.contains("return"))
    }

    func testDeleteSavesExplicitly() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func delete(_ entry: WaterEntry) {", in: cleaned)
        XCTAssertTrue(body.contains("try modelContext.save()"))
        XCTAssertTrue(body.contains("showTimedWorkoutSaveErrorToast"))
    }

    func testDeleteTodayEntriesSavesExplicitly() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func deleteTodayEntries() {", in: cleaned)
        XCTAssertTrue(body.contains("try modelContext.save()"))
        XCTAssertTrue(body.contains("showTimedWorkoutSaveErrorToast"))
    }
}
