#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md,
/// Testfall 15 "App-Neustart erhaelt Analyseergebnisse und ausstehende
/// Vorschlaege"). Vorbild: `CardioGoalEditorPersistenceTests.
/// testSavedCardioGoalSurvivesARealStoreRestart` - ein echter
/// `ModelContainer`-Neustart (neue Instanz auf derselben Store-Datei), nicht
/// nur In-Memory-Retention.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class RaceProgressPersistenceTests: XCTestCase {

    func testRaceProgressLastAnalyzedAtSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("race-progress-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        let analyzedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let enabledAt = Date(timeIntervalSince1970: 1_740_000_000)
        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext
            let profile = UserBodyProfile(
                birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
                cardioCoachingEnabled: true, cardioGoal: .marathon
            )
            context.insert(profile)
            try context.save()

            profile.cardioCoachingEnabledAt = enabledAt
            RaceProgressDueCalculator.recordAnalysisCompleted(
                for: profile, configurationFingerprint: "marathon#raceDateA", now: analyzedAt, in: context
            )
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let profile = try XCTUnwrap(try reopened.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first)
        XCTAssertEqual(profile.cardioCoachingEnabledAt, enabledAt)
        XCTAssertEqual(profile.raceProgressLastAnalyzedAt, analyzedAt)
        XCTAssertEqual(profile.raceProgressLastAnalyzedConfigurationFingerprint, "marathon#raceDateA")
    }
}
#endif
