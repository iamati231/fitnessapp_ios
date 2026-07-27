#if canImport(SwiftData)
import XCTest
@testable import FitnessAppData

/// DEL-209: Whitelist-Settings-Portabilität. Nutzt eine isolierte
/// UserDefaults-Suite, damit Tests den echten App-State nicht anfassen.
final class SettingsPortabilityTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "SettingsPortabilityTests"

    override func setUpWithError() throws {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    func testRoundtripPreservesAllKinds() {
        defaults.set("lbs", forKey: "weight_unit")
        defaults.set(true, forKey: "pref_water_reminder")
        defaults.set(2, forKey: "pref_water_reminder_hours")
        defaults.set(false, forKey: "pref_timer_sound")

        let collected = SettingsPortability.collect(from: defaults)

        let target = UserDefaults(suiteName: suiteName + ".target")!
        target.removePersistentDomain(forName: suiteName + ".target")
        defer { target.removePersistentDomain(forName: suiteName + ".target") }

        let result = SettingsPortability.apply(collected, to: target)
        XCTAssertEqual(result.applied, 4)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(target.string(forKey: "weight_unit"), "lbs")
        XCTAssertTrue(target.bool(forKey: "pref_water_reminder"))
        XCTAssertEqual(target.integer(forKey: "pref_water_reminder_hours"), 2)
        XCTAssertFalse(target.bool(forKey: "pref_timer_sound"))
    }

    func testUntouchedKeysAreNotCollected() {
        // Nichts gesetzt → leere Sammlung; der Import lässt Ziel-Defaults
        // unangetastet statt sie mit Pseudo-Werten zu überschreiben.
        XCTAssertTrue(SettingsPortability.collect(from: defaults).isEmpty)
    }

    func testUnknownKeysAreRejected() {
        // Sicherheits-Invariante: ein manipuliertes ZIP darf keine
        // beliebigen UserDefaults schreiben.
        //
        // DEL-230: Der frühere `XCTAssertNil(...forKey: "AppleLanguages")`
        // konnte NIE halten. `AppleLanguages` ist ein System-Key: UserDefaults
        // loest ihn ueber die globale Domain auf und liefert immer die
        // Sprachliste des Geraets zurueck — voellig unabhaengig davon, ob die
        // App je etwas geschrieben hat. Der Test behauptete also eine
        // Sicherheitsluecke, wo keine war. Die Invariante selbst hielt: der
        // Key wurde korrekt als `skipped` gezaehlt.
        //
        // Richtige Pruefung fuer einen System-Key ist deshalb nicht "ist nil",
        // sondern "wurde nicht auf unseren Wert gesetzt".
        let languagesBefore = defaults.array(forKey: "AppleLanguages") as? [String]

        let result = SettingsPortability.apply([
            ("isResetting", "true"),                 // internes Crash-Gate
            ("AppleLanguages", "hacked"),            // System-Key
            ("weight_unit", "kg"),                   // legitim
        ], to: defaults)

        XCTAssertEqual(result.applied, 1)
        XCTAssertEqual(result.skipped, 2)
        // App-eigener, nicht-gewhitelisteter Key: der darf wirklich nil bleiben.
        XCTAssertNil(defaults.object(forKey: "isResetting"))
        // System-Key: unveraendert, insbesondere nicht auf "hacked".
        XCTAssertNotEqual(defaults.string(forKey: "AppleLanguages"), "hacked")
        XCTAssertEqual(defaults.array(forKey: "AppleLanguages") as? [String], languagesBefore)
        XCTAssertEqual(defaults.string(forKey: "weight_unit"), "kg")
    }

    func testMalformedValuesAreSkipped() {
        let result = SettingsPortability.apply([
            ("pref_water_reminder", "banana"),       // kein Bool
            ("pref_water_reminder_hours", "drei"),   // kein Int
        ], to: defaults)
        XCTAssertEqual(result.applied, 0)
        XCTAssertEqual(result.skipped, 2)
    }
}
#endif
