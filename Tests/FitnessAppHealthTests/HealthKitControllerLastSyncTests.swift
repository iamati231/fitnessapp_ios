import XCTest
@testable import FitnessAppHealth

/// Settings-Epic Phase 4 (Befund SV-F13): "letzter Sync" muss einen Kaltstart
/// ueberleben. Vorher war `lastSyncDate` rein In-Memory und ging bei jedem
/// Neustart verloren — wirkte dann wie "noch nie synchronisiert", obwohl laengst
/// erfolgreich geschrieben wurde. Der eigentliche Schreibpfad
/// (`markSyncSucceeded()`, ausschliesslich nach einem nachweislich erfolgreichen
/// `saveMeasurement`/`saveWorkout`) ist `private` und nur ueber echtes HealthKit
/// erreichbar — auf Linux nicht pruefbar. Dieser Test deckt die andere Haelfte
/// ab, die tatsaechlich Pure-Foundation ist: dass ein bereits gespeicherter
/// Zeitstempel beim naechsten `init()` korrekt geladen wird (bzw. `nil` bleibt,
/// wenn nie erfolgreich synchronisiert wurde).
final class HealthKitControllerLastSyncTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "HealthKitControllerLastSyncTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testInitLoadsAPreviouslyPersistedTimestamp() async {
        let defaults = makeDefaults()
        let stored = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(stored, forKey: HealthKitController.lastSyncDateDefaultsKey)

        let lastSyncDate = await MainActor.run { HealthKitController(userDefaults: defaults).lastSyncDate }

        XCTAssertEqual(lastSyncDate, stored)
    }

    /// Niemals synchronisiert = ehrliches `nil`, nie ein frei erfundener
    /// Zeitstempel oder "heute".
    func testInitWithNothingStoredLeavesLastSyncDateNil() async {
        let defaults = makeDefaults()
        let lastSyncDate = await MainActor.run { HealthKitController(userDefaults: defaults).lastSyncDate }
        XCTAssertNil(lastSyncDate)
    }

    /// Audit-Fund: `fetchWorkoutWindows` warf frueher auf einer Plattform ohne
    /// HealthKit (hier: `swift test` laeuft auf macOS) still `[]` zurueck, statt
    /// wie die eigene Doc-Aussage ("THROWS instead of returning [] on failure")
    /// zu werfen — der Caller (`WorkoutHealthExportService.prepare`) haette eine
    /// fehlgeschlagene Abfrage faelschlich als "noch nichts in Health" gelesen
    /// und beim naechsten Export-Versuch Duplikate geschrieben.
    func testFetchWorkoutWindowsThrowsRatherThanReturningEmptyWhenHealthKitIsUnavailable() async {
        let controller = await MainActor.run { HealthKitController(userDefaults: makeDefaults()) }
        do {
            _ = try await controller.fetchWorkoutWindows(from: Date(), to: Date())
            XCTFail("Expected fetchWorkoutWindows to throw when HealthKit is unavailable, not return a value")
        } catch {
            // Any thrown error is correct here — the contract is "never silently empty".
        }
    }
}
