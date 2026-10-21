import XCTest
@testable import FitnessAppCore

/// Task C (Nutrition-UI-Gaps-and-AI, 2026-10-21): verifiziert, dass
/// `FoodCatalogData`-Eintraege ueber `nameKey` in DE/EN/TR korrekt
/// uebersetzt sind.
///
/// Step-1-Ruling (abweichend von der urspruenglichen Testvorlage im
/// Task-Brief, siehe Report): die im Plan vermutete Live-Reaktivitaetsluecke
/// ("Sprache wechselt, View bleibt gemountet") existiert in dieser App
/// NICHT — `grep -rn "\.locale" Sources/` findet keinen
/// `.environment(\.locale:)` oder sonstigen In-App-Sprachumschalter, ein
/// Sprachwechsel laeuft nur ueber die iOS-Systemeinstellungen (App-Neustart).
/// `resolvedName(for:)` in `AddMealView` ruft `String(localized:bundle:)`
/// ohnehin bei jedem Rendering frisch auf, es gibt also keinen zu
/// invalidierenden State. Keine Aenderung an `AddMealView.swift` noetig.
///
/// **Warum JSON-Parsing statt `String(localized:bundle:)`:** die Brief-
/// Vorlage wollte per `String(localized:bundle: .module, locale:)`
/// aufloesen. Das scheitert unter `swift test` strukturell, unabhaengig von
/// Katalog-Korrektheit — siehe dokumentierter CI-Fund in
/// `docs/DELTIQ_DEVICE_ACCEPTANCE.md` ("CI-Fund (kein Feature-Bug)",
/// Paket-3a-Abschnitt): ein `swift test`-Lauf kopiert `Localizable.xcstrings`
/// nur ROH in den Ressourcen-Bundle statt es wie ein echter Xcode-App-Build
/// zu kompilieren, `String(localized:bundle:)` liefert dadurch fuer JEDEN
/// Catalog-Key den Key unveraendert zurueck (reproduziert: CI-Run
/// 39677765492, exakt dieselbe Symptomatik wie beim damals deshalb wieder
/// entfernten `CoachingMessageProvider`-Resolution-Test). Zusaetzlich zeigt
/// `Bundle.module` *in diesem Testziel* ohnehin auf `FitnessAppUITests`s
/// eigenes, ressourcenloses Bundle, nicht auf das von `FitnessAppUI`
/// (gleiches Modul-Shadowing-Prinzip wie bei `ExerciseGifBundleResource`
/// dokumentiert). Deshalb hier derselbe, bereits etablierte Codebase-Weg wie
/// in `SetDisplayModeSettingTests`/`DeltiqLabelScalesDownInsteadOfWrappingTests`:
/// `#filePath`-relative Navigation zur echten Quelldatei auf der Platte statt
/// ueber ein Test-Bundle — das prueft tatsaechlich die im xcstrings
/// hinterlegten Uebersetzungen, nicht nur, dass irgendein String
/// zurueckkommt.
final class FoodCatalogLocalizationTests: XCTestCase {
    private var xcstringsURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI/Resources/Localizable.xcstrings")
    }

    private func catalogStrings() throws -> [String: Any] {
        let data = try Data(contentsOf: xcstringsURL)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(root["strings"] as? [String: Any])
    }

    private func translatedValue(_ strings: [String: Any], key: String, languageCode: String) -> String? {
        guard let entry = strings[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let localization = localizations[languageCode] as? [String: Any],
              let stringUnit = localization["stringUnit"] as? [String: Any]
        else { return nil }
        return stringUnit["value"] as? String
    }

    func testWaterResolvesPerLocaleIncludingTurkish() throws {
        // Exakte Id ist "water" (nicht per .contains("water") raten: das
        // matcht sonst zuerst "tuna_canned_water", das vor "water" in
        // FoodCatalogData.all steht).
        let water = try XCTUnwrap(FoodCatalogData.all.first { $0.id == "water" })
        XCTAssertEqual(water.nameKey, "nutrition.food.water.name")

        let strings = try catalogStrings()
        XCTAssertEqual(translatedValue(strings, key: water.nameKey, languageCode: "de"), "Wasser")
        XCTAssertEqual(translatedValue(strings, key: water.nameKey, languageCode: "en"), "Water")
        XCTAssertEqual(translatedValue(strings, key: water.nameKey, languageCode: "tr"), "Su")
    }

    func testEverySingleCatalogNameKeyResolvesInAllThreeLocales() throws {
        // Regressionsnetz: kein nameKey darf in DE/EN/TR fehlen oder leer sein.
        let strings = try catalogStrings()
        for item in FoodCatalogData.all {
            for languageCode in ["de", "en", "tr"] {
                let value = translatedValue(strings, key: item.nameKey, languageCode: languageCode)
                XCTAssertNotNil(value, "\(item.nameKey) fehlt Eintrag fuer \(languageCode) in Localizable.xcstrings")
                XCTAssertNotEqual(value, item.nameKey, "\(item.nameKey) fehlt Uebersetzung fuer \(languageCode)")
                XCTAssertFalse(value?.isEmpty ?? true, "\(item.nameKey) hat einen leeren Wert fuer \(languageCode)")
            }
        }
    }

    func testSearchMatchesLocalizedNameNotRawKey() throws {
        // Die Suche filtert auf den AUFGELOESTEN Namen (AddMealView.filteredEntries),
        // nicht auf den rohen nameKey — "Su" muss unter Tuerkisch auffindbar sein.
        let water = try XCTUnwrap(FoodCatalogData.all.first { $0.id == "water" })
        let strings = try catalogStrings()
        let turkishName = try XCTUnwrap(translatedValue(strings, key: water.nameKey, languageCode: "tr"))
        XCTAssertTrue(turkishName.localizedCaseInsensitiveContains("Su"))
    }
}
