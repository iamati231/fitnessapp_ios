import XCTest

/// Audit-Fund (sechster Follow-up-UI-Audit): `repairAll` schluckte einen
/// fehlgeschlagenen `context.save()` mit `try?` - `runIfNeeded` setzte den
/// `doneKey` danach trotzdem, weil `repaired` weiterhin > 0 war. Anders als
/// die anderen Migrationen in diesem Ordner (idempotent ueber Neu-Erkennung)
/// kann diese Migration bei gesetztem Flag nie wieder retryen. Quelltext-
/// Pruefung, weil `save()` keinen Test-Seam fuer einen echten Fehlschlag hat.
final class SessionDurationRepairSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/FitnessAppUI/Migration/SessionDurationRepair.swift"),
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

    /// A failed save must make `repairAll` return `nil`, the same signal
    /// already used for a failed fetch — so `runIfNeeded` (`guard let
    /// repaired = repairAll(...) else { return 0 }`) never sets `doneKey`
    /// on a save that didn't actually persist.
    func testRepairAllReturnsNilWhenSaveThrows() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private static func repairAll(in context: ModelContext) -> Int? {") else {
            return XCTFail("repairAll(in:) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("function end not found")
        }
        let body = cleaned[funcStart.upperBound..<funcEnd.lowerBound]

        guard let ifRange = body.range(of: "if repaired > 0 {") else {
            return XCTFail("the save must stay gated on repaired > 0, same as before")
        }
        guard let tryRange = body.range(of: "try context.save()", range: ifRange.upperBound..<body.endIndex) else {
            return XCTFail("must use do/catch instead of try? to detect a failed save")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let catchEnd = body.range(of: "\n            }", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("return nil"),
                      "a failed save must return nil, the same signal runIfNeeded uses for a failed fetch")
    }

    /// `runIfNeeded` must still only set `doneKey` when `repairAll` returned
    /// non-nil (unchanged, but pinned here so a future edit can't silently
    /// reintroduce the bug by setting the flag unconditionally).
    func testRunIfNeededOnlySetsDoneKeyWhenRepairAllSucceeded() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "public static func runIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) -> Int {") else {
            return XCTFail("runIfNeeded(in:defaults:) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("function end not found")
        }
        let body = cleaned[funcStart.upperBound..<funcEnd.lowerBound]

        guard let guardRange = body.range(of: "guard let repaired = repairAll(in: context) else { return 0 }") else {
            return XCTFail("runIfNeeded must bail out via repairAll's nil, not set doneKey unconditionally")
        }
        guard let setFlagRange = body.range(of: "defaults.set(true, forKey: doneKey)", range: guardRange.upperBound..<body.endIndex) else {
            return XCTFail("doneKey must still be set on the success path")
        }
        XCTAssertTrue(setFlagRange.lowerBound > guardRange.upperBound)
    }
}
