import XCTest

/// Modul-12-Audit (Migration), Fund 3. `repairAll` mutierte `durationMinutes`
/// bereits VOR dem `try context.save()` - schlug der Save fehl, blieben diese
/// Mutationen dirty auf dem geteilten `ModelContext` liegen und konnten von
/// einem spaeteren, unabhaengigen Save andernorts still mit persistiert
/// werden. `context.rollback()` ist projektweit verboten; stattdessen muessen
/// die hier selbst beruehrten Sessions im Fehlerfall einzeln zurueckgesetzt
/// werden - dasselbe Snapshot/Revert-Muster wie bei den uebrigen
/// "mutate-then-save"-Funden dieses Audits. Quelltext-Pruefung, weil
/// `repairAll` `private` ist und `save()` keinen Test-Seam fuer einen echten
/// Fehlschlag hat.
final class SessionDurationRepairRollbackTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Migration/SessionDurationRepair.swift"),
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

    private static func body(of signature: String, in text: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            throw XCTSkip("\(signature) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            throw XCTSkip("end of \(signature) not found")
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testRepairAllSnapshotsDurationBeforeMutating() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private static func repairAll(in context: ModelContext) -> Int? {", in: cleaned)

        guard let snapshotRange = body.range(of: "let before = session.durationMinutes") else {
            return XCTFail("must snapshot durationMinutes before calling repairDuration()")
        }
        guard let repairRange = body.range(of: "session.repairDuration()", range: snapshotRange.upperBound..<body.endIndex) else {
            return XCTFail("snapshot must happen BEFORE repairDuration() mutates durationMinutes")
        }
        XCTAssertTrue(repairRange.lowerBound > snapshotRange.upperBound,
                      "the snapshot must be taken before the mutating call")
    }

    func testRepairAllRevertsTouchedSessionsOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private static func repairAll(in context: ModelContext) -> Int? {", in: cleaned)

        XCTAssertFalse(body.contains("context.rollback()"),
                       "must never call context.rollback() - it would roll back the entire shared ModelContext")

        guard let tryRange = body.range(of: "try context.save()") else {
            return XCTFail("must call context.save() via do/catch")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let catchEnd = body.range(of: "\n                return nil", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block must still return nil on failure")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]

        XCTAssertTrue(catchBody.contains("session.durationMinutes = original"),
                      "a failed save must revert durationMinutes on every session this function itself touched")
    }
}
