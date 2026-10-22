# Online-Lebensmittelsuche (Open Food Facts) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wenn ein Lebensmittel lokal keinen Treffer hat, kann der Nutzer — nach explizitem Opt-in und nur bei Netzverfügbarkeit — über Open Food Facts online suchen, einen Treffer wählen, die Nährwerte vor dem Speichern prüfen/korrigieren und erst nach Bestätigung einen neuen lokalen Katalogeintrag anlegen.

**Architecture:** Ein neues, isoliertes SPM-Modul `FitnessAppFoodLookup` kapselt den gesamten Netzwerkzugriff (einzige Netzwerk-Komponente der App, keine Abhängigkeit zu/von `FitnessAppAI`). `FoodCatalogEntry` bekommt zwei additive Felder (`displayName`, `isOnlineImported`), damit online importierte Einträge Klartext-Namen statt xcstrings-Keys tragen und als Nutzerdaten (Export/Wipe) statt Katalogdaten behandelt werden. Die UI verdrahtet zwei bestehende "kein Treffer"-Zustände in `AddMealView.swift` auf denselben Suchen→Wählen→Vorschau→Bestätigen-Flow.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData, `URLSession` (erster Netzwerk-Code der App), Open Food Facts / Search-a-licious REST-API.

**Spec:** `docs/superpowers/specs/2026-10-22-online-food-lookup-design.md`

## Global Constraints

- Netzwerkzugriff NUR in `FitnessAppFoodLookup` — nie in `FitnessAppAI`, `FitnessAppCore`, `FitnessAppData` oder direkt in UI-Code.
- Netzwerkzugriff NUR nach explizitem Opt-in (Settings-Toggle, Standard aus).
- Jede Anfrage trägt einen identifizierenden `User-Agent` im Format `AppName/Version (ContactEmail)` (Open-Food-Facts-Vorgabe).
- Suchanfragen: max. 10/Min/IP (dokumentiertes Limit) — kein Search-as-you-type, nur auf expliziten Nutzer-Tap.
- Kein Nährwert wird je erfunden/interpoliert — fehlendes API-Feld bleibt leer, nie 0 oder geraten.
- Neuer Katalogeintrag entsteht ausschließlich nach expliziter Bestätigung in einer Vorschau (kein Auto-Save aus dem Suchergebnis).
- Jeder neue sichtbare Text geht über `Sources/FitnessAppUI/Resources/Localizable.xcstrings` (DE/EN/TR).
- Rundung/Formatierung ausschließlich über `Sources/FitnessAppCore/Numerics/DoubleFormatting.swift` — keine neue Rundungslogik.
- SwiftData: rein additive Felder auf `FoodCatalogEntry`, kein `VersionedSchema`/`SchemaMigrationPlan`.
- Online importierte Katalogeinträge (`isOnlineImported == true`) sind Nutzerdaten: von `UserDataWipe`/`DataExportService`/`DataImportService` erfasst; die ~100 seedierten Einträge bleiben davon unberührt.
- ODbL-Attribution für Open Food Facts ist sichtbar, sobald das Feature genutzt wird.
- Kein Merge, kein Release, kein Push zu main als Teil dieses Plans — jede Task endet mit lokalem Commit, Push nur zu diesem bestehenden Feature-Branch für CI-Zugriff (siehe Ruling im Ledger des vorherigen Plans).
- Verifikation ausschließlich über macOS-CI (`swift build`/`swift test` via `apple-ci-comparison.yml`) — **keine TestingBot-Gerätetests** für diesen Plan (explizite Nutzervorgabe).

## Review Focus

- **Unvollständige Open-Food-Facts-Antworten:** crowd-gesourcte Daten haben oft nur einen Teil der Makros gesetzt — ein Treffer mit kcal aber ohne Protein/Kohlenhydrate/Fett darf nicht mit 0 aufgefüllt werden; die Vorschau muss fehlende Felder sichtbar leer lassen.
- **Mehrfach-Button-in-einer-Row-Bug (C1 aus der vorherigen finalen Review):** die neue Trefferliste darf nicht denselben Fehler wiederholen (mehrere Default-Buttons in einer Form/List-Row lösen beim Tap alle Actions aus) — von Anfang an mit separaten Rows oder `.buttonStyle(.borderless)` bauen, nicht nachträglich flicken.
- **Rate-Limit/Doppeltipp:** schnelles wiederholtes Tippen auf "Online suchen" darf nicht mehrere parallele Anfragen auslösen (Rate-Limit 10/Min) — Aktion während laufender Anfrage deaktivieren, analog zum bereits gelösten KI-Doppeltipp-Schutz aus Task E des vorherigen Plans.
- **Export/Wipe-Fehlklassifizierung:** ein Bug, der `isOnlineImported`-Einträge nicht korrekt von seedierten Katalogeinträgen unterscheidet, könnte entweder Nutzerdaten beim Reset behalten (Datenschutz-Erwartung verletzt) oder versehentlich seedierte Katalogdaten löschen (App bricht) — beide Richtungen brauchen einen Test.
- **Kein Netz beim Tippen auf "Online suchen":** darf nie zu einem leeren/hängenden Ladezustand führen — sofortiger, lokalisierter Hinweis plus funktionierender Rückweg zur manuellen Erfassung.

---

### Task 1: `FitnessAppFoodLookup` — Netzwerk-Client, Werttypen, Fehlerfälle

**Vor Implementierung zwingend:** die exakte Such-API-Form ist bereits recherchiert (siehe unten), aber das **Antwort-Schema pro Treffer (`hits[]`) ist in der offiziellen OpenAPI-Spec nicht typisiert** (`"items":{"type":"object"}`) — vor Schritt 3 einen echten Request gegen `https://search.openfoodfacts.org/search?q=<bekanntes Produkt, z.B. nutella>&page_size=1&langs=de` ausführen (z.B. via `curl` mit einem echten `User-Agent`-Header) und die tatsächlichen Feldnamen in `hits[]` (insbesondere `product_name`, `nutriments` mit `energy-kcal_100g`/`proteins_100g`/`carbohydrates_100g`/`fat_100g`) gegen die Annahmen unten verifizieren, bevor die Decodable-Typen final festgelegt werden. Ergebnis als Kommentarblock am Kopf von `OnlineFoodSearchClient.swift` festhalten (analog zum Foundation-Models-Recherche-Kommentar aus dem vorherigen Plan).

**Bereits recherchierte API-Fakten (verifiziert gegen die offizielle OpenAPI-Spec, Stand dieser Planung):**
- Basis: `https://search.openfoodfacts.org` (Search-a-licious API, OpenAPI 3.1.0).
- Freitext-Suche: `GET /search?q=<Suchtext>&langs=<Sprachcode>&page_size=<n>&fields=<kommagetrennt>&sort_by=<Feld>`.
- Erfolgs-Antwort (`SuccessSearchResponse`) hat mindestens: `hits` (Array), `page`, `page_size`, `page_count`, `count`, `is_count_exact`, `took`, `timed_out`, `debug`.
- Fehler-Antwort (`ErrorSearchResponse`): `debug`, `errors` (je `title`/`description`).
- Rate-Limit (offizielle Doku, altes v2/legacy-Limit, als Richtwert übernehmen): 10 Suchanfragen/Min/IP, HTTP 503 bei globalem Limit.
- `User-Agent`-Pflicht-Format: `AppName/Version (ContactEmail)`.
- Bekanntes Nutriments-Key-Pattern aus einer realen Produktantwort (v2-Produkt-Endpunkt, nicht Suche, aber dasselbe zugrunde liegende Datenmodell): `energy-kcal_100g`, `carbohydrates_100g` bestätigt; `proteins_100g`/`fat_100g` folgen mit hoher Wahrscheinlichkeit demselben `<nutrient>_100g`-Muster, aber NICHT aus einer Suchantwort bestätigt — das ist genau die oben geforderte Verifikation vor Schritt 3.

**Files:**
- Create: `Sources/FitnessAppFoodLookup/OnlineFoodCandidate.swift`
- Create: `Sources/FitnessAppFoodLookup/OnlineFoodSearchError.swift`
- Create: `Sources/FitnessAppFoodLookup/OnlineFoodSearchClient.swift`
- Modify: `Package.swift` (neues Target/Produkt `FitnessAppFoodLookup` + Test-Target, Abhängigkeit nur zu `FitnessAppCore`)
- Test: `Tests/FitnessAppFoodLookupTests/OnlineFoodSearchClientTests.swift`

**Interfaces:**
- Produziert (für Task 2-5):
  ```swift
  public struct OnlineFoodCandidate: Sendable, Equatable, Identifiable {
      public let id: String              // Open-Food-Facts-Produktcode oder generierte UUID als Fallback
      public let name: String
      public let brand: String?
      public let kcalPer100g: Double?
      public let proteinPer100g: Double?
      public let carbsPer100g: Double?
      public let fatPer100g: Double?
  }
  public enum OnlineFoodSearchError: Error, Sendable, Equatable {
      case noNetwork
      case rateLimited
      case noResults
      case invalidResponse
  }
  public protocol OnlineFoodSearching: Sendable {
      func search(query: String, locale: Locale) async throws -> [OnlineFoodCandidate]
  }
  public struct OpenFoodFactsSearchClient: OnlineFoodSearching {
      public init(userAgent: String)
      public func search(query: String, locale: Locale) async throws -> [OnlineFoodCandidate]
  }
  ```

- [ ] **Step 1: Failing Tests gegen einen Fake-`URLProtocol`**

Mindestens: gültige Antwort mit vollständigen Nährwerten → Candidates mit allen Feldern gefüllt; Antwort mit teilweise fehlenden Nährwerten (z.B. ohne `proteins_100g`) → entsprechendes Feld `nil`, NICHT 0; leeres `hits`-Array → `OnlineFoodSearchError.noResults`; HTTP 503 → `.rateLimited`; kein Netz (simuliert über einen Fake, der `URLError(.notConnectedToInternet)` wirft) → `.noNetwork`; ungültiges/unparsbares JSON → `.invalidResponse`, kein Force-Unwrap-Crash. Nutze einen injizierten `URLProtocol`-Mock oder eine Fake-`URLSession`-Abstraktion (kein echter Netzwerkaufruf in Tests).

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

Run: `swift test --filter OnlineFoodSearchClientTests` (lokal auf Windows für `FitnessAppFoodLookup` möglich, da reines `URLSession`+`Foundation`, kein SwiftData/UIKit).
Expected: FAIL (Typen existieren noch nicht).

- [ ] **Step 3: Implementieren**

`OpenFoodFactsSearchClient.search(query:locale:)` baut die GET-Anfrage gegen `https://search.openfoodfacts.org/search` mit den oben recherchierten (und in Schritt "vor Implementierung" verifizierten) Query-Parametern, setzt den `User-Agent`-Header, deckt die Fehlerfälle aus Schritt 1 ab, und mappt jeden `hits[]`-Eintrag auf `OnlineFoodCandidate` — fehlende Nährwert-Felder werden `nil`, nie 0.

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

Run: `swift test --filter OnlineFoodSearchClientTests`
Expected: PASS.

- [ ] **Step 5: `swift build` für das gesamte Package, Commit**

```bash
swift build
git add Package.swift Sources/FitnessAppFoodLookup Tests/FitnessAppFoodLookupTests
git commit -m "feat: add FitnessAppFoodLookup module for Open Food Facts search"
```

---

### Task 2: `FoodCatalogEntry` — Klartext-Namen, Online-Import-Markierung, Nutzerdaten-Scope

**Voraussetzung:** keine (unabhängig von Task 1, kann parallel geplant werden, läuft aber danach in der Sequenz dieses Plans, da Task 4 beide Interfaces braucht).

**Files:**
- Modify: `Sources/FitnessAppData/FoodCatalogEntry.swift`
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift:589-591` (`resolvedName(for:)`)
- Modify: `Sources/FitnessAppData/Export/UserDataWipe.swift`
- Modify: `Sources/FitnessAppData/Export/DataExportService.swift`
- Modify: `Sources/FitnessAppData/Export/DataImportService.swift`
- Test: `Tests/FitnessAppDataTests/FoodCatalogEntryOnlineImportTests.swift`

**Interfaces:**
- Konsumiert: `OnlineFoodCandidate` aus Task 1 (nur als Parameter-Typ für den neuen Initializer, keine SwiftData-Abhängigkeit auf `FitnessAppFoodLookup` — `FitnessAppData` importiert `FitnessAppFoodLookup` nicht; der Initializer nimmt stattdessen einfache Skalare entgegen, die UI-Schicht in Task 4 mappt `OnlineFoodCandidate` auf diese Parameter).
- Produziert (für Task 4/5):
  ```swift
  extension FoodCatalogEntry {
      public var isOnlineImported: Bool { get set }   // Default false bei bestehendem init(from:)
      public var displayName: String? { get set }     // nil bei bestehendem init(from:)
      public convenience init(
          displayName: String,
          category: FoodCategory,
          kcalPer100g: Double,
          proteinPer100g: Double,
          carbsPer100g: Double,
          fatPer100g: Double
      )  // generiert eine neue UUID als catalogID, setzt isOnlineImported = true
  }
  ```

- [ ] **Step 1: Failing Test — Namensauflösung bevorzugt `displayName`**

```swift
func testResolvedNamePrefersDisplayNameOverNameKey() {
    let entry = FoodCatalogEntry(displayName: "Linsensuppe", category: .other,
                                  kcalPer100g: 90, proteinPer100g: 5, carbsPer100g: 12, fatPer100g: 2)
    XCTAssertTrue(entry.isOnlineImported)
    XCTAssertEqual(entry.displayName, "Linsensuppe")
}
```
(Die eigentliche `resolvedName(for:)`-Präzedenz wird in `Tests/FitnessAppUITests/` getestet, da die Funktion `private` in `AddMealView` ist — siehe Step 3.)

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

Run: `swift test --filter FoodCatalogEntryOnlineImportTests`
Expected: FAIL (Initializer/Felder existieren noch nicht).

- [ ] **Step 3: Implementieren**

`isOnlineImported: Bool = false` und `displayName: String? = nil` additiv auf `FoodCatalogEntry` ergänzen (SwiftData-Migration bleibt additiv, kein `VersionedSchema`). Neuer `convenience init` wie oben, generiert `catalogID` über `UUID().uuidString`. In `AddMealView.swift:589-591` `resolvedName(for:)` erweitern: `entry.displayName ?? String(localized: ...)` — `displayName` hat Vorrang. `UserDataWipe.swift`'s `deleteSharedUserData` löscht `FoodCatalogEntry`-Zeilen mit `isOnlineImported == true` (Fetch-Predicate, keine pauschale Löschung aller `FoodCatalogEntry`). `DataExportService.swift`/`DataImportService.swift` bekommen eine neue `online_food_catalog.csv`-Export-/Import-Funktion nach dem Muster von `buildMeals`/`meals.csv` (`DataExportService.swift:147`) — nur Zeilen mit `isOnlineImported == true`.

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen + Export/Wipe-Regressionstest**

Zusätzlicher Test: ein geseedeter Katalogeintrag (`isOnlineImported == false`) UND ein online importierter Eintrag existieren gleichzeitig — nach `deleteSharedUserData` ist nur der online importierte weg, der geseedete bleibt. Export erfasst nur den online importierten in `online_food_catalog.csv`.
Run: `swift test --filter FoodCatalogEntryOnlineImportTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppData Sources/FitnessAppUI/Nutrition/AddMealView.swift Tests/FitnessAppDataTests
git commit -m "feat: add online-imported food catalog entries as user data"
```

---

### Task 3: Opt-in-Einstellung + ODbL-Attribution

**Voraussetzung:** keine.

**Files:**
- Modify: `Sources/FitnessAppUI/Settings/SettingsDataConnectionsView.swift` (Vorbild: bestehender `externalWorkoutImportEnabled`-Toggle, Zeile 90)
- Create: `Sources/FitnessAppUI/Settings/OnlineFoodLookupCreditsView.swift` (Vorbild: `ExerciseMediaCreditsView.swift`)
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: `Tests/FitnessAppUITests/OnlineFoodLookupSettingPersistenceTests.swift` (falls ein bestehendes Persistenz-Test-Muster für `@AppStorage`-ähnliche Toggles existiert — gleiches Muster wie für `externalWorkoutImportEnabled` übernehmen, Pfad nach eigener Recherche im Repo festlegen)

**Interfaces:**
- Produziert (für Task 4/5): einen lesbaren Zustand, z.B. `@AppStorage("onlineFoodLookupEnabled") private var onlineFoodLookupEnabled: Bool = false` nach demselben Persistenz-Mechanismus wie `externalWorkoutImportEnabled` — exakten Mechanismus (AppStorage vs. UserBodyProfile-Feld) aus dem bestehenden Toggle in `SettingsDataConnectionsView.swift:90` übernehmen, nicht neu erfinden.

- [ ] **Step 1: Recherche des bestehenden Toggle-Persistenz-Musters**

`externalWorkoutImportEnabled` in `SettingsDataConnectionsView.swift` nachschlagen: ist es `@AppStorage`, ein `UserBodyProfile`-Feld, oder etwas anderes? Das exakt gleiche Muster für `onlineFoodLookupEnabled` verwenden.

- [ ] **Step 2: Toggle + Attribution implementieren**

Neuer Toggle "Online-Suche für unbekannte Lebensmittel" (Default aus) mit kurzem Erklärtext, Platzierung neben `externalWorkoutImportEnabled`. `OnlineFoodLookupCreditsView.swift` nach dem Muster von `ExerciseMediaCreditsView.swift`: Open-Food-Facts-Name, ODbL-Lizenzhinweis, Link zur Projektseite (`openfoodfacts.org`) als sichtbarer Text, erreichbar über die Settings (z.B. verlinkt direkt neben dem neuen Toggle oder in der bestehenden Credits-Sektion).

- [ ] **Step 3: Test laufen lassen (falls ein Persistenz-Test existiert), `swift build`**

Run: `swift build` (Sanity-Check lokal) + CI-Lauf (`apple-ci-comparison.yml`) für den echten UI-Build/Test.

- [ ] **Step 4: Commit**

```bash
git add Sources/FitnessAppUI/Settings Sources/FitnessAppUI/Resources/Localizable.xcstrings
git commit -m "feat: add opt-in setting and attribution for online food lookup"
```

---

### Task 4: `AddMealView` — Online-Suche aus der manuellen Suche (0 Treffer)

**Voraussetzung:** Tasks 1, 2, 3 abgeschlossen.

**Files:**
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift:181-182` (bestehender `nutrition.addMeal.noResults`-Zustand)
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: Erweiterung von `Tests/FitnessAppUITests/` (Dateiname nach Repo-Konvention, z.B. `OnlineFoodLookupFlowTests.swift`)

**Interfaces:**
- Konsumiert: `OnlineFoodSearching`/`OpenFoodFactsSearchClient`/`OnlineFoodCandidate`/`OnlineFoodSearchError` aus Task 1; `FoodCatalogEntry`'s neuer `convenience init` aus Task 2; `onlineFoodLookupEnabled` aus Task 3.
- Produziert (für Task 5): eine wiederverwendbare Trefferlisten-Komponente und eine Vorschau/Bestätigen-Sheet-Komponente (exakte Namen nach eigener Wahl beim Implementieren, aber als `View`/Funktion extrahiert, NICHT private inline in einer einzigen Verzweigung versteckt — Task 5 muss sie von einem zweiten Aufrufer aus wiederverwenden können, ohne Code zu duplizieren). Im Report den exakten Namen/Signatur für Task 5 festhalten.

- [ ] **Step 1: Failing Tests**

Mindestens: `onlineFoodLookupEnabled == false` → keine "Online suchen"-Aktion sichtbar (heutiges Verhalten unverändert); `== true` + kein Netz → lokalisierter Hinweis statt leerem Ladezustand, manuelle Erfassung bleibt bedienbar; `== true` + Netz + mehrere Treffer → Trefferliste zeigt alle, ein Tap auf einen bestimmten Treffer wählt GENAU diesen aus (Regressionstest gegen C1 — mit einem Fake, der 3+ Candidates liefert, prüfen, dass jeder einzeln antippbar ist und nicht der letzte immer gewinnt); Bestätigen in der Vorschau legt einen `FoodCatalogEntry` mit `isOnlineImported == true` an und fügt ihn der aktuellen Mahlzeit hinzu über den bestehenden `addItem`-Pfad (keine neue Persistenz-Logik); Abbrechen in der Vorschau legt NICHTS an.

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

Run: CI-Lauf (`apple-ci-comparison.yml`) — Swift-UI-Tests brauchen das echte Target, nicht nur `FitnessAppCore` auf Windows.
Expected: FAIL.

- [ ] **Step 3: Implementieren**

"Online suchen"-Aktion im bestehenden `nutrition.addMeal.noResults`-Zustand (sichtbarer Text-Label, kein icon-only Control). Trefferliste: **von Anfang an mit `.buttonStyle(.borderless)` pro Zeile oder als separate, einzeln tappbare Rows bauen** (nicht die in der finalen Review gefundene Mehrfach-Button-Falle wiederholen). Vorschau-Sheet: Name (editierbar, vorausgefüllt aus `OnlineFoodCandidate.name`) + Makros/100g (editierbar, vorausgefüllt, fehlende Felder bleiben leer). Bestätigen ruft Task 2's neuen `FoodCatalogEntry`-Initializer auf und hängt den Eintrag über den bestehenden `addItem`/`save()`-Pfad an die Mahlzeit.

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

Run: CI-Lauf, Expected: PASS. Dead-Key-Audit: `python .scripts/dead_catalog_v3.py` lokal ausführen, `UNUSED: 0` bestätigen (reales Ergebnis im Report zeigen, nicht nur behaupten).

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Nutrition/AddMealView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests
git commit -m "feat: add online food search from manual search no-results state"
```

---

### Task 5: `AddMealView` — Online-Suche aus einem KI-Kandidaten ohne Katalogtreffer

**Voraussetzung:** Task 4 abgeschlossen (wiederverwendet dessen Trefferlisten-/Vorschau-Komponenten).

**Files:**
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift` (bestehende `aiCandidateRow`, `hasNoCatalogMatch`-Zweig — exakte Zeilen nach Task 4's finalem Stand im eigenen Report nachschlagen, nicht aus diesem Plan raten, da Task 4 die Datei verändert)
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: Erweiterung derselben Testdatei wie Task 4

**Interfaces:**
- Konsumiert: die in Task 4's Report dokumentierten exakten Trefferlisten-/Vorschau-Komponentennamen (NICHT neu bauen).

- [ ] **Step 1: Failing Test**

Ein KI-Kandidat mit `hasNoCatalogMatch == true` zeigt eine "Online suchen"-Aktion, vorausgefüllt mit `MealDraftCandidate.foodText`; Tap startet denselben Flow wie Task 4, mit demselben C1-Regressionstest (mehrere Treffer, korrekter Einzel-Tap) wiederholt für diesen zweiten Einstiegspunkt.

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

Run: CI-Lauf, Expected: FAIL.

- [ ] **Step 3: Implementieren**

Zweite Aufrufstelle für Task 4's Trefferlisten-/Vorschau-Komponenten in der `hasNoCatalogMatch`-Verzweigung von `aiCandidateRow`, vorausgefüllt mit `foodText`. Keine Duplikation der Flow-Logik aus Task 4.

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

Run: CI-Lauf, Expected: PASS. Dead-Key-Audit erneut: `UNUSED: 0` bestätigen.

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Nutrition/AddMealView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests
git commit -m "feat: add online food search from AI candidate with no catalog match"
```
