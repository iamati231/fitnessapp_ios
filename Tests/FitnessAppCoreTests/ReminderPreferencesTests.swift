import XCTest
@testable import FitnessAppCore

final class ReminderPreferencesTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "ReminderPreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    /// Fehlender Key = Vorgabewert (wie bei `@AppStorage`), NICHT `false` wie
    /// bei `UserDefaults.bool(forKey:)` — die Oberflaeche zeigt dort den
    /// Schalter AN.
    func testMissingKeysResolveToTheSettingsDefaults() {
        let prefs = ReminderPreferences.load(from: makeDefaults())
        XCTAssertEqual(prefs, ReminderPreferences(
            waterEnabled: true, waterIntervalHours: 3,
            measurementEnabled: true, measurementWeekday: 1, measurementHour: 8
        ))
    }

    func testStoredValuesAreRespected() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: ReminderPreferences.waterEnabledKey)
        defaults.set(2, forKey: ReminderPreferences.waterIntervalHoursKey)
        defaults.set(false, forKey: ReminderPreferences.measurementEnabledKey)
        defaults.set(4, forKey: ReminderPreferences.measurementWeekdayKey)
        defaults.set(18, forKey: ReminderPreferences.measurementHourKey)

        let prefs = ReminderPreferences.load(from: defaults)
        XCTAssertFalse(prefs.waterEnabled)
        XCTAssertEqual(prefs.waterIntervalHours, 2)
        XCTAssertFalse(prefs.measurementEnabled)
        XCTAssertEqual(prefs.measurementWeekday, 4)
        XCTAssertEqual(prefs.measurementHour, 18)
    }

    func testExplicitTrueIsRespected() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: ReminderPreferences.waterEnabledKey)
        defaults.set(true, forKey: ReminderPreferences.measurementEnabledKey)

        let prefs = ReminderPreferences.load(from: defaults)
        XCTAssertTrue(prefs.waterEnabled)
        XCTAssertTrue(prefs.measurementEnabled)
    }

    func testImplausibleValuesFallBackToTheDefaults() {
        let defaults = makeDefaults()
        defaults.set(0, forKey: ReminderPreferences.waterIntervalHoursKey)
        defaults.set(9, forKey: ReminderPreferences.measurementWeekdayKey)
        defaults.set(30, forKey: ReminderPreferences.measurementHourKey)

        let prefs = ReminderPreferences.load(from: defaults)
        XCTAssertEqual(prefs.waterIntervalHours, 3)
        XCTAssertEqual(prefs.measurementWeekday, 1)
        XCTAssertEqual(prefs.measurementHour, 8)
    }

    func testBoundaryValuesAreAccepted() {
        let defaults = makeDefaults()
        defaults.set(1, forKey: ReminderPreferences.waterIntervalHoursKey)
        defaults.set(7, forKey: ReminderPreferences.measurementWeekdayKey)
        defaults.set(0, forKey: ReminderPreferences.measurementHourKey)

        let prefs = ReminderPreferences.load(from: defaults)
        XCTAssertEqual(prefs.waterIntervalHours, 1)
        XCTAssertEqual(prefs.measurementWeekday, 7)
        XCTAssertEqual(prefs.measurementHour, 0)
    }

    /// Die Keys muessen zu den `@AppStorage`-Keys der SettingsView passen,
    /// sonst liest die Planung andere Werte als die Oberflaeche anzeigt.
    func testKeysMatchTheSettingsViewAppStorageKeys() {
        XCTAssertEqual(ReminderPreferences.waterEnabledKey, "pref_water_reminder")
        XCTAssertEqual(ReminderPreferences.waterIntervalHoursKey, "pref_water_reminder_hours")
        XCTAssertEqual(ReminderPreferences.measurementEnabledKey, "pref_measurement_reminder")
        XCTAssertEqual(ReminderPreferences.measurementWeekdayKey, "pref_measurement_reminder_weekday")
        XCTAssertEqual(ReminderPreferences.measurementHourKey, "pref_measurement_reminder_hour")
    }
}
