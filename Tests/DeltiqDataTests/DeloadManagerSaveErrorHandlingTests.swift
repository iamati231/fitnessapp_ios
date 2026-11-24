import XCTest

/// Modul-9-Audit (Dashboard): `startDeload`/`endDeload` mutierten Exercise-
/// Felder VOR `context.save()` ohne Rollback bei Fehlschlag - die Mutation
/// blieb live im ModelContext und konnte durch einen spaeteren, unabhaengigen
/// Autosave trotzdem landen, ohne dass der Caller je vom Fehlschlag erfuhr.
/// Quelltext-Pruefung, weil `save()` keinen Test-Seam fuer einen echten
/// Fehlschlag hat (gleiches Muster wie `DashboardViewSaveErrorHandlingTests`).
final class DeloadManagerSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqData/DeloadManager.swift"),
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

    func testStartDeloadRollsBackOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "public static func startDeload(", in: cleaned)

        guard let tryRange = body.range(of: "try context.save()") else {
            return XCTFail("must call context.save() via do/catch")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found — a failed save must not leave mutated Exercise fields live")
        }
        guard let catchEnd = body.range(of: "\n            throw error", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block must re-throw so the caller learns of the failure")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("deloadOriginalWeight = nil"),
                      "rollback must clear the snapshot flag it just set")
        XCTAssertTrue(catchBody.contains("suggestedWeight = change.original"),
                      "rollback must restore the pre-reduction weight")
    }

    func testEndDeloadRollsBackOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "public static func endDeload(", in: cleaned)

        guard let tryRange = body.range(of: "try context.save()") else {
            return XCTFail("must call context.save() via do/catch")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found — a failed save must not leave restored Exercise fields live")
        }
        guard let catchEnd = body.range(of: "\n            throw error", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block must re-throw so the caller learns of the failure")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("suggestedWeight = original.suggestedWeight"),
                      "rollback must restore the still-reduced weight")
        XCTAssertTrue(catchBody.contains("deloadOriginalWeight = original.deloadOriginalWeight"),
                      "rollback must restore the snapshot flag it just cleared")
    }
}
