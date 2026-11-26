#if canImport(SwiftData) && canImport(UIKit)
import XCTest
import SwiftData
@testable import DeltiqUI
import DeltiqData
import DeltiqCore

/// Audit-Fund Modul 19: `detect()` haengte `.weeklyMilestone` an, BEVOR
/// geprueft wurde, ob die bewertete Session (per `now`) ueberhaupt Teil der
/// aktuellen Kalenderwoche ist - der `thisInWeek`-Guard kam erst danach.
/// Reproduziert das reine Datenmodell-Verhalten (ohne SwiftUI-Rendering).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class WorkoutAchievementDetectorNowPinningTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeSession(startTime: Date, context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(startTime: startTime, endTime: startTime, isCompleted: true)
        context.insert(session)
        return session
    }

    func testWeeklyMilestoneNotShownForASessionOutsideTheCurrentWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let week = try XCTUnwrap(Calendar.current.dateInterval(of: .weekOfYear, for: now))

        // Die bewertete Session liegt klar ausserhalb der aktuellen Woche.
        let oldSession = makeSession(startTime: week.start.addingTimeInterval(-86_400), context: context)
        // Drei ANDERE Sessions IN der aktuellen Woche - genug fuer das
        // Weekly-Milestone-Kriterium (>= 3), wenn man (fehlerhaft) nicht
        // prueft, ob `oldSession` selbst dazugehoert.
        let other1 = makeSession(startTime: week.start.addingTimeInterval(3_600), context: context)
        let other2 = makeSession(startTime: week.start.addingTimeInterval(7_200), context: context)
        let other3 = makeSession(startTime: week.start.addingTimeInterval(10_800), context: context)
        try context.save()

        let result = WorkoutAchievementDetector.detect(
            session: oldSession,
            history: [oldSession, other1, other2, other3],
            now: now
        )

        XCTAssertTrue(result.isEmpty, "a session outside the current week must not receive a weeklyMilestone attributed to it")
    }

    func testWeeklyMilestoneStillShownWhenSessionIsInCurrentWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let week = try XCTUnwrap(Calendar.current.dateInterval(of: .weekOfYear, for: now))

        let thisSession = makeSession(startTime: week.start.addingTimeInterval(3_600), context: context)
        let other1 = makeSession(startTime: week.start.addingTimeInterval(7_200), context: context)
        let other2 = makeSession(startTime: week.start.addingTimeInterval(10_800), context: context)
        try context.save()

        let result = WorkoutAchievementDetector.detect(
            session: thisSession,
            history: [thisSession, other1, other2],
            now: now
        )

        XCTAssertTrue(result.contains {
            if case .weeklyMilestone(let count) = $0.kind { return count == 3 }
            return false
        }, "a session that is genuinely part of the current week must still get its weeklyMilestone")
    }

    // MARK: - Source-Inspection: Call-Site pinnt `now` jetzt explizit

    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent() // this file
                    .deletingLastPathComponent() // DeltiqUITests
                    .deletingLastPathComponent() // Tests
                    .appendingPathComponent("Sources/DeltiqUI/Workout/WorkoutSummaryView.swift"),
                encoding: .utf8
            )
        }
    }

    func testAchievementsCallSitePinsNowToSessionEndTime() throws {
        XCTAssertTrue(
            try source.contains("now: session.endTime"),
            "achievements must pass a stable now instead of relying on detect()'s .now default, which is re-evaluated on every access of this computed property"
        )
    }
}
#endif
