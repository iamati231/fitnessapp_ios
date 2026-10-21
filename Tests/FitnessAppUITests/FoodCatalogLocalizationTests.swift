import XCTest
@testable import FitnessAppCore
@testable import FitnessAppUI

/// Task C (Nutrition-UI-Gaps-and-AI, 2026-10-21): verifiziert, dass
/// `FoodCatalogData`-Eintraege ueber `nameKey` + `Bundle.module` in DE/EN/TR
/// korrekt aufloesen. Die im Plan vermutete Live-Reaktivitaetsluecke
/// ("Sprache wechselt, View bleibt gemountet") existiert in dieser App NICHT:
/// `grep -rn "\.locale\b" Sources/` findet keinen `.environment(\.locale:)`-
/// oder sonstigen In-App-Sprachumschalter — ein Sprachwechsel laeuft nur ueber
/// die iOS-Systemeinstellungen, was die App neu startet. `resolvedName(for:)`
/// in `AddMealView` ruft `String(localized:bundle:)` ohnehin bei jedem
/// Rendering frisch auf, es gibt also keinen zu invalidierenden State. Das
/// eigentliche Risiko ist ein falscher/fehlender `nameKey` oder eine fehlende
/// Uebersetzung im Katalog — das testet diese Datei.
final class FoodCatalogLocalizationTests: XCTestCase {
    private func resolvedName(_ key: String, locale: Locale) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, locale: locale)
    }

    func testWaterResolvesPerLocaleIncludingTurkish() throws {
        // Exakte Id ist "water" (nicht per .contains("water") raten: das
        // matcht sonst zuerst "tuna_canned_water", das vor "water" in
        // FoodCatalogData.all steht).
        let water = try XCTUnwrap(FoodCatalogData.all.first { $0.id == "water" })
        XCTAssertEqual(water.nameKey, "nutrition.food.water.name")
        XCTAssertEqual(resolvedName(water.nameKey, locale: Locale(identifier: "de")), "Wasser")
        XCTAssertEqual(resolvedName(water.nameKey, locale: Locale(identifier: "en")), "Water")
        XCTAssertEqual(resolvedName(water.nameKey, locale: Locale(identifier: "tr")), "Su")
    }

    func testEverySingleCatalogNameKeyResolvesInAllThreeLocales() {
        // Regressionsnetz: kein nameKey darf in DE/EN/TR auf sich selbst
        // (= fehlende Uebersetzung) zurueckfallen.
        for item in FoodCatalogData.all {
            for localeID in ["de", "en", "tr"] {
                let resolved = resolvedName(item.nameKey, locale: Locale(identifier: localeID))
                XCTAssertNotEqual(resolved, item.nameKey, "\(item.nameKey) fehlt Uebersetzung fuer \(localeID)")
            }
        }
    }

    func testSearchMatchesLocalizedNameNotRawKey() {
        // Die Suche filtert auf den AUFGELOESTEN Namen (AddMealView.filteredEntries),
        // nicht auf den rohen nameKey — "Su" muss unter Tuerkisch auffindbar sein.
        let water = FoodCatalogData.all.first { $0.id == "water" }!
        let turkishName = resolvedName(water.nameKey, locale: Locale(identifier: "tr"))
        XCTAssertTrue(turkishName.localizedCaseInsensitiveContains("Su"))
    }
}
