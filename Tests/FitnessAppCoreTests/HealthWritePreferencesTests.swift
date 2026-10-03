import XCTest
@testable import FitnessAppCore

final class HealthWritePreferencesTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "HealthWritePreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    /// Fehlender Key = Vorgabewert (wie bei `@AppStorage`), NICHT `false` wie
    /// bei `UserDefaults.bool(forKey:)` — Kraft ist vorbelegt AN.
    func testMissingKeysResolveToTheDefaults() {
        let prefs = HealthWritePreferences.load(from: makeDefaults())
        XCTAssertTrue(prefs.strengthEnabled)
        XCTAssertFalse(prefs.cardioEnabled)
        XCTAssertEqual(prefs, HealthWritePreferences())
    }

    /// Festnageln: Die `@AppStorage`-Deklarationen der Oberflaeche lesen diese
    /// Konstanten; aendert sich eine, muss dieser Test bewusst mitziehen.
    func testDefaultConstants() {
        XCTAssertEqual(HealthWritePreferences.defaultStrengthEnabled, true)
        XCTAssertEqual(HealthWritePreferences.defaultCardioEnabled, false)
    }

    func testStoredValuesAreRespected() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: HealthWritePreferences.strengthEnabledKey)
        defaults.set(true, forKey: HealthWritePreferences.cardioEnabledKey)

        let prefs = HealthWritePreferences.load(from: defaults)
        XCTAssertFalse(prefs.strengthEnabled)
        XCTAssertTrue(prefs.cardioEnabled)
    }

    func testOnlyOneKeyStoredLeavesTheOtherAtItsDefault() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: HealthWritePreferences.cardioEnabledKey)

        let prefs = HealthWritePreferences.load(from: defaults)
        XCTAssertTrue(prefs.strengthEnabled, "fehlender Kraft-Key = Vorgabe AN")
        XCTAssertTrue(prefs.cardioEnabled)
    }

    /// Ein Wert anderen Typs (z.B. aus einer fremden Datei) zaehlt als
    /// nicht gesetzt statt als `false`.
    func testNonBoolValueFallsBackToTheDefault() {
        let defaults = makeDefaults()
        defaults.set("an", forKey: HealthWritePreferences.strengthEnabledKey)
        defaults.set("aus", forKey: HealthWritePreferences.cardioEnabledKey)

        XCTAssertEqual(HealthWritePreferences.load(from: defaults), HealthWritePreferences())
    }

    func testKeysMatchTheAppStorageKeys() {
        XCTAssertEqual(HealthWritePreferences.strengthEnabledKey, "pref_healthkit_write_strength")
        XCTAssertEqual(HealthWritePreferences.cardioEnabledKey, "pref_healthkit_write_cardio")
    }

    func testEnabledCategoriesAndIsEnabled() {
        XCTAssertEqual(HealthWritePreferences().enabledCategories, [.strength])
        XCTAssertEqual(
            HealthWritePreferences(strengthEnabled: true, cardioEnabled: true).enabledCategories,
            [.strength, .cardio]
        )
        XCTAssertEqual(
            HealthWritePreferences(strengthEnabled: false, cardioEnabled: false).enabledCategories,
            []
        )
        let prefs = HealthWritePreferences(strengthEnabled: false, cardioEnabled: true)
        XCTAssertFalse(prefs.isEnabled(.strength))
        XCTAssertTrue(prefs.isEnabled(.cardio))
    }
}
