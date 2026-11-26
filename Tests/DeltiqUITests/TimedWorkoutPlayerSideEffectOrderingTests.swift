import XCTest

/// Audit-Fund (Modul 20): `finishTimedSession` loeste `HealthWorkoutWriter.pushLive(...)`
/// und die PR-Celebration-Notification VOR dem abschliessenden `modelContext.save()`
/// aus. Schlaegt der Save fehl und gelingt er beim erneuten "Speichern"-Tap (siehe
/// `TimedWorkoutPlayerSaveErrorHandlingTests`), liefen beide externen, nicht
/// wiederholbaren Seiteneffekte doppelt. Quelltext-Pruefung wie dort, da `save()`
/// keinen Test-Seam fuer einen echten Fehlschlag hat.
final class TimedWorkoutPlayerSideEffectOrderingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/TimedWorkoutPlayerView.swift"),
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

    func testPushLiveHappensOnlyAfterSuccessfulSave() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "func finishTimedSession(") else {
            return XCTFail("finishTimedSession not found")
        }
        guard let catchReturn = cleaned.range(of: "} catch {\n        return false\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("finishTimedSession must catch a failed save and return false")
        }
        guard let pushLive = cleaned.range(of: "HealthWorkoutWriter.pushLive(", range: catchReturn.upperBound..<cleaned.endIndex) else {
            return XCTFail("HealthWorkoutWriter.pushLive(...) not found after the catch block")
        }
        XCTAssertTrue(pushLive.lowerBound > catchReturn.upperBound,
                      "pushLive must only run AFTER the catch block, i.e. only on a successful save - otherwise a retry after a failed save double-writes to HealthKit")
    }

    func testPRCelebrationTaskHappensOnlyAfterSuccessfulSave() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "func finishTimedSession(") else {
            return XCTFail("finishTimedSession not found")
        }
        guard let catchReturn = cleaned.range(of: "} catch {\n        return false\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("finishTimedSession must catch a failed save and return false")
        }
        guard let celebrationTask = cleaned.range(of: "await prNotifications.scheduleCelebration(", range: catchReturn.upperBound..<cleaned.endIndex) else {
            return XCTFail("prNotifications.scheduleCelebration(...) not found after the catch block")
        }
        XCTAssertTrue(celebrationTask.lowerBound > catchReturn.upperBound,
                      "the PR celebration notification must only be scheduled AFTER the catch block - otherwise a retry after a failed save fires it twice")
    }

    /// `detectedPR`/`celebration` muessen weiterhin VOR dem Save berechnet werden -
    /// `recordTimedFormatPR` mutiert den modelContext und muss Teil desselben Save sein.
    func testPRDetectionStillHappensBeforeSave() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "func finishTimedSession(") else {
            return XCTFail("finishTimedSession not found")
        }
        guard let detect = cleaned.range(of: "PersonalRecordSync.recordTimedFormatPR(", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("PersonalRecordSync.recordTimedFormatPR(...) not found")
        }
        guard let catchReturn = cleaned.range(of: "} catch {\n        return false\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("finishTimedSession must catch a failed save and return false")
        }
        XCTAssertTrue(detect.lowerBound < catchReturn.upperBound,
                      "PR detection must stay BEFORE the save so it is part of the same persisted transaction")
    }
}
