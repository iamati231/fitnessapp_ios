#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Dashboard-Fix "doppelte Coach-Karten" (Verifikations-Nachfrage, Punkt 4):
/// bestehende Widget-Einstellungen (inkl. einer manuell deaktivierten
/// `.raceProgressCard`) muessen einen echten App-Neustart ueberleben -
/// Vorbild: `RaceProgressPersistenceTests.
/// testRaceProgressLastAnalyzedAtSurvivesARealStoreRestart` - ein echter
/// `ModelContainer`-Neustart (neue Instanz auf derselben Store-Datei), nicht
/// nur In-Memory-Retention.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DashboardWidgetPersistenceTests: XCTestCase {

    func testCustomWidgetOrderWithRaceProgressCardDisabledSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dashboard-widget-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        // Nutzer hat beide Karten aktiv, raceProgressCard dann manuell wieder
        // deaktiviert und eine eigene Reihenfolge fuer den Rest gewaehlt.
        let customOrder: [DashboardWidgetType] = [.runCoachCard, .nutrition, .nextWorkout, .trophyRoom]
        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext
            let profile = UserBodyProfile(
                birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
                cardioCoachingEnabled: true
            )
            context.insert(profile)
            try context.save()

            profile.activeDashboardWidgets = customOrder
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let profile = try XCTUnwrap(try reopened.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first)
        XCTAssertEqual(profile.activeDashboardWidgets, customOrder,
                       "die vom Nutzer gewaehlte Reihenfolge inkl. deaktivierter raceProgressCard muss nach einem echten Neustart unveraendert sein")
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.raceProgressCard))
        XCTAssertTrue(profile.activeDashboardWidgets.contains(.runCoachCard))
    }

    /// Ein Profil, das VOR der Einfuehrung von `.raceProgressCard` gespeichert
    /// wurde (gespeichertes Raw-Array enthaelt den Case schlicht nicht - der
    /// additive Enum-Case braucht keine Migration), behaelt sein Bestands-Set
    /// unveraendert nach einem echten Neustart; `.raceProgressCard` erscheint
    /// nicht automatisch, muss vom Nutzer bewusst in den Einstellungen
    /// aktiviert werden.
    func testPreExistingRawWidgetListWithoutRaceProgressCardStaysUnchangedAfterARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dashboard-widget-persistence-legacy-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }
        let legacyRaw = ["nextWorkout", "runCoachCard", "coachingInsight", "weeklyVolume"]

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext
            let profile = UserBodyProfile(
                birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
                cardioCoachingEnabled: true
            )
            context.insert(profile)
            profile.activeDashboardWidgetsRaw = legacyRaw
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let profile = try XCTUnwrap(try reopened.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first)
        XCTAssertEqual(profile.activeDashboardWidgetsRaw, legacyRaw,
                       "Bestands-Raw-Array ohne raceProgressCard darf nach einem Neustart nicht veraendert/aufgefuellt werden")
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.raceProgressCard))
    }
}
#endif
