# Deltiq Ernährungsassistent — Erster Zuschnitt (v1, ohne KI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lokale, deterministische Mahlzeiten- und Ernährungserfassung (Katalog, manuelle Erfassung, Vorschau, Tagesübersicht, optionale Ziele) als Dashboard-Kachel — ohne jede KI-Komponente.

**Architecture:** Neue Typen in den drei bestehenden Modulen, kein neues Package. `FitnessAppCore` bekommt den statischen Katalog + reine Berechnungsfunktionen (Linux/Windows-testbar). `FitnessAppData` bekommt drei neue `@Model`-Typen (`FoodCatalogEntry`, `MealEntry`, `MealItem`) plus einen eigenen, von `LibrarySeeder` unabhängigen `FoodCatalogSeeder`. `FitnessAppUI` bekommt die Erfassungs-/Übersichts-Screens und die Dashboard-Kachel. Das spätere `FitnessAppAI`-Modul (Spec Abschnitt 8) ist NICHT Teil dieses Plans.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, XCTest (bestehende Target-Struktur, keine neuen Dependencies).

**Spec:** `C:\Users\a.isik\Downloads\Deltiq_Erna88hrungsassistent_Spec_fuer_Claude_Code.md` (Abschnitte 1–7, 9–11 — Abschnitt 8 "Lokale KI" ist explizit außerhalb dieses Plans)

## Global Constraints

- App-Mindestziel bleibt iOS 17 / macOS 14 (`Package.swift` unverändert) — keine KI-spezifischen `@available`-Gates in diesem Plan nötig.
- Sprachen: Deutsch, Englisch, Türkisch — jeder neue sichtbare Text geht über `Sources/FitnessAppUI/Resources/Localizable.xcstrings`, nie hartkodiert.
- Rundung/Formatierung: ausschließlich bestehende `Double`-Extensions aus `Sources/FitnessAppCore/Numerics/DoubleFormatting.swift` (`truncated(to:)`, `formattedWholeOrTwoDecimals`, `formattedTwoDecimals`) — keine neue Rundungslogik.
- SwiftData: rein additive `@Model`-Typen, Eintrag in `Sources/FitnessAppData/AppSchema.swift`, kein `VersionedSchema`/`SchemaMigrationPlan` (Projekt-Konvention, siehe `BaselineAssessment.swift`-Kommentar).
- `Sources/FitnessAppData/LibrarySeeder.swift` wird NICHT verändert — der Katalog bekommt einen eigenen Seeder.
- Gramm ist Standardmengeneinheit; Stück nur mit `pieceWeightGrams`; Milliliter nur mit `densityGramsPerMl` — niemals pauschal 1 ml = 1 g.
- Vorschau erzeugt keine gespeicherte Mahlzeit; Speichern nur nach explizitem Bestätigen-Tap; Abbrechen verwirft jeden Entwurf ohne Persistenz-Spur; ein Speicherfehler behält den Entwurf und zeigt keinen Erfolg.
- Historische `MealItem`-Nährwert-Snapshots ändern sich nie rückwirkend durch spätere Katalogänderungen.
- Keine neuen Kalorienziele/Trainingsverbrauch-Automatik über das hier Beschriebene hinaus (Tagesziele sind rein manuell oder per einmaliger TDEE-Übernahme, nie live gekoppelt oder automatisch verrechnet).
- `DashboardWidgetType` wächst additiv (neuer Case ans Ende) — Bestandsnutzer dürfen nie automatisch die neue Kachel aktiv bekommen, Neuinstallationen schon.
- Kein Merge, kein Release als Teil dieses Plans — jede Task endet mit einem lokalen Commit, keine PR/kein Push.
- Keine Ernährungsdaten (Lebensmittelnamen, Mengen, Nährwerte) in Logs oder Debug-Ausgaben (Spec Abschnitt 9) — kein `print`/`debugPrint` auf diesen Werten in neuem Code.
- Bedienelemente für Speichern/Abbrechen/Bearbeiten/Löschen bekommen immer einen sichtbaren Text-Label (kein icon-only Control ohne `Text`), identisch zur bestehenden Konvention in `WaterTrackerView`/`TDEEView`.

## Review Focus

- **Doppeltap auf Speichern beim Erfassen:** zwei schnelle Taps dürfen nie zwei `MealEntry`-Zeilen erzeugen → Test in Task 6.
- **Milliliter ohne Dichte:** ein Katalogeintrag ohne `densityGramsPerMl` darf die Einheit "ml" nie anbieten, auch nicht über einen Edge-Case im Mengen-Picker → Test in Task 2 (Core-Berechnung liefert `nil`) und Task 6 (UI bietet die Einheit nicht an).
- **Katalogänderung nach dem Speichern:** wird ein `FoodCatalogEntry` nach dem Speichern einer Mahlzeit geändert oder gelöscht, darf sich der gespeicherte `MealItem`-Snapshot nicht rückwirkend ändern → Test in Task 4.
- **Abbrechen lässt keine Spur:** Abbrechen einer neuen oder bearbeiteten Mahlzeit nach Hinzufügen mehrerer Positionen darf keine `MealEntry`/`MealItem`-Zeile im Store hinterlassen → Test in Task 6/7.
- **Speicherfehler zeigt keinen Erfolg:** schlägt der Persistenz-Aufruf fehl, bleibt der Entwurf editierbar und es erscheint keine Erfolgsmeldung → Test in Task 6 (injizierbarer Persistenz-Closure).

---

### Task 1: Lokaler Lebensmittelkatalog (Core)

**Files:**
- Create: `Sources/FitnessAppCore/Nutrition/FoodCatalogItem.swift`
- Create: `Sources/FitnessAppCore/Nutrition/FoodCategory.swift`
- Create: `Sources/FitnessAppCore/Nutrition/FoodCatalogData.swift`
- Test: `Tests/FitnessAppCoreTests/FoodCatalogDataTests.swift`

**Interfaces:**
- Produces: `public struct FoodCatalogItem: Identifiable, Sendable, Codable` mit `id: String`, `nameKey: String`, `category: FoodCategory`, `kcalPer100g: Double`, `proteinPer100g: Double`, `carbsPer100g: Double`, `fatPer100g: Double`, `defaultServingGrams: Double?`, `servingNameKey: String?`, `pieceWeightGrams: Double?`, `densityGramsPerMl: Double?`.
- Produces: `public enum FoodCategory: String, Codable, Sendable, CaseIterable` mit Cases `meat, fish, dairy, egg, grain, vegetable, fruit, legume, nutSeed, fat, beverage, sweet` und `var localizationKey: String { "nutrition.category.\(rawValue).name" }` (Muster: `DashboardWidgetType.localizationKey`).
- Produces: `public enum FoodCatalogData { public static let all: [FoodCatalogItem] }`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FitnessAppCore

final class FoodCatalogDataTests: XCTestCase {
    func testAllIDsAreUnique() {
        let ids = FoodCatalogData.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Doppelte Katalog-IDs")
    }

    func testCatalogHasAtLeast100Items() {
        XCTAssertGreaterThanOrEqual(FoodCatalogData.all.count, 100)
    }

    func testMillilitersRequireExplicitDensity() {
        // Spec 4.2: ml darf NIE pauschal angenommen werden — jeder Eintrag
        // mit densityGramsPerMl muss ihn bewusst gesetzt haben (>0), kein
        // Eintrag darf 0 oder negativ tragen.
        for item in FoodCatalogData.all {
            if let density = item.densityGramsPerMl {
                XCTAssertGreaterThan(density, 0, "\(item.id): densityGramsPerMl muss > 0 sein")
            }
        }
    }

    func testPieceUnitRequiresPositivePieceWeight() {
        for item in FoodCatalogData.all {
            if let pieceWeight = item.pieceWeightGrams {
                XCTAssertGreaterThan(pieceWeight, 0, "\(item.id): pieceWeightGrams muss > 0 sein")
            }
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FoodCatalogDataTests`
Expected: FAIL (Modul/Typen existieren noch nicht)

- [ ] **Step 3: Implement `FoodCategory`, `FoodCatalogItem`, `FoodCatalogData`**

`FoodCategory` exakt wie bei `DashboardWidgetType`: `String, Codable, Sendable, CaseIterable`, eine `localizationKey`-computed-property, keine weitere Logik.

`FoodCatalogItem` ist ein reiner, unveränderlicher Werttyp (kein `class`, kein SwiftData-Import) — ein `memberwise init` reicht, keine Validierung im Typ selbst (Validierung lebt in den Tests/Daten, nicht im Typ, YAGNI: der Typ wird nur aus vertrauenswürdigen statischen Literalen konstruiert).

`FoodCatalogData.all`: ~100 `FoodCatalogItem`-Literale, deutsche Alltagslebensmittel, grob nach `FoodCategory` gruppiert (Kommentar-Überschriften wie in `ExerciseLibraryData.swift`). Jeder `nameKey` folgt dem Muster `"nutrition.food.\(id).name"`; `id` ist ein stabiler, lesbarer Slug (z. B. `"chicken_breast_raw"`, `"chicken_breast_cooked"` — rohe/gegarte Variante sind laut Spec 4.2 getrennte Einträge). `densityGramsPerMl` NUR bei echten Flüssigkeiten setzen (Milch ≈ 1.03, Öl ≈ 0.92, Wasser = 1.0) — bei allem anderen `nil` lassen. `pieceWeightGrams` nur bei stückbaren Lebensmitteln (Ei, Scheibe Brot, Banane).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FoodCatalogDataTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppCore/Nutrition/FoodCatalogItem.swift Sources/FitnessAppCore/Nutrition/FoodCategory.swift Sources/FitnessAppCore/Nutrition/FoodCatalogData.swift Tests/FitnessAppCoreTests/FoodCatalogDataTests.swift
git commit -m "feat: add local food catalog data (Core)"
```

---

### Task 2: Nährwert-Mengenberechnung (Core)

**Files:**
- Modify: `Sources/FitnessAppCore/Nutrition/NutritionCalculations.swift`
- Create: `Sources/FitnessAppCore/Nutrition/FoodUnit.swift`
- Create: `Sources/FitnessAppCore/Nutrition/NutrientValues.swift`
- Test: `Tests/FitnessAppCoreTests/NutritionCalculationsTests.swift`

**Interfaces:**
- Consumes: `FoodCatalogItem` (Task 1).
- Produces: `public enum FoodUnit: String, Codable, Sendable, CaseIterable { case gram, piece, milliliter }`.
- Produces: `public struct NutrientValues: Sendable, Codable, Equatable { public let kcal: Double; public let proteinG: Double; public let carbsG: Double; public let fatG: Double; public static let zero: NutrientValues; public static func sum(_ values: [NutrientValues]) -> NutrientValues }`.
- Produces: `public static func NutritionCalculations.nutrients(for item: FoodCatalogItem, quantity: Double, unit: FoodUnit) -> NutrientValues?` — `nil` wenn `quantity <= 0`, oder `unit == .piece` ohne `item.pieceWeightGrams`, oder `unit == .milliliter` ohne `item.densityGramsPerMl`.
- Produces: `public extension FoodCatalogItem { func supports(_ unit: FoodUnit) -> Bool }` — `.gram` immer `true`, `.piece` nur wenn `pieceWeightGrams != nil`, `.milliliter` nur wenn `densityGramsPerMl != nil`. Wird von Task 6 benutzt, um im Mengen-Picker ausschließlich zulässige Einheiten anzuzeigen.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FitnessAppCore

final class NutritionCalculationsTests: XCTestCase {
    let chicken = FoodCatalogItem(
        id: "test_chicken", nameKey: "x", category: .meat,
        kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6,
        defaultServingGrams: nil, servingNameKey: nil,
        pieceWeightGrams: nil, densityGramsPerMl: nil
    )
    let milk = FoodCatalogItem(
        id: "test_milk", nameKey: "x", category: .dairy,
        kcalPer100g: 64, proteinPer100g: 3.3, carbsPer100g: 4.8, fatPer100g: 3.6,
        defaultServingGrams: nil, servingNameKey: nil,
        pieceWeightGrams: nil, densityGramsPerMl: 1.03
    )
    let egg = FoodCatalogItem(
        id: "test_egg", nameKey: "x", category: .egg,
        kcalPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11,
        defaultServingGrams: nil, servingNameKey: nil,
        pieceWeightGrams: 60, densityGramsPerMl: nil
    )

    func testGramScalesLinearly() {
        let result = NutritionCalculations.nutrients(for: chicken, quantity: 200, unit: .gram)
        XCTAssertEqual(result?.kcal, 330)
        XCTAssertEqual(result?.proteinG, 62)
    }

    func testMillilitersUsesExplicitDensityNotOneToOne() {
        // 100 ml Milch wiegt 103 g, nicht 100 g — Spec 4.2
        let result = NutritionCalculations.nutrients(for: milk, quantity: 100, unit: .milliliter)
        XCTAssertEqual(result?.kcal, 64 * 1.03, accuracy: 0.0001)
    }

    func testMillilitersWithoutDensityReturnsNil() {
        XCTAssertNil(NutritionCalculations.nutrients(for: chicken, quantity: 100, unit: .milliliter))
    }

    func testPieceWithoutPieceWeightReturnsNil() {
        XCTAssertNil(NutritionCalculations.nutrients(for: chicken, quantity: 1, unit: .piece))
    }

    func testPieceUsesPieceWeight() {
        let result = NutritionCalculations.nutrients(for: egg, quantity: 2, unit: .piece)
        XCTAssertEqual(result?.kcal, 155 * 1.2, accuracy: 0.0001) // 2 × 60g = 120g
    }

    func testNonPositiveQuantityReturnsNil() {
        XCTAssertNil(NutritionCalculations.nutrients(for: chicken, quantity: 0, unit: .gram))
        XCTAssertNil(NutritionCalculations.nutrients(for: chicken, quantity: -5, unit: .gram))
    }

    func testSumAddsAllFields() {
        let a = NutrientValues(kcal: 100, proteinG: 10, carbsG: 5, fatG: 2)
        let b = NutrientValues(kcal: 50, proteinG: 2, carbsG: 8, fatG: 1)
        let total = NutrientValues.sum([a, b])
        XCTAssertEqual(total.kcal, 150)
        XCTAssertEqual(total.carbsG, 13)
    }

    func testSupportsReflectsAvailableUnitsOnly() {
        XCTAssertTrue(chicken.supports(.gram))
        XCTAssertFalse(chicken.supports(.piece))
        XCTAssertFalse(chicken.supports(.milliliter))
        XCTAssertTrue(milk.supports(.milliliter))
        XCTAssertTrue(egg.supports(.piece))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NutritionCalculationsTests`
Expected: FAIL

- [ ] **Step 3: Implement `FoodUnit`, `NutrientValues`, `NutritionCalculations.nutrients(for:quantity:unit:)`**

`NutrientValues` ist reiner Daten-Container, `sum` ist ein simples `reduce(.zero) { ... }`. `nutrients(for:quantity:unit:)`: Gramm-Basis ist immer `kcalPer100g * grams / 100` usw.; für `.piece` wird `quantity * pieceWeightGrams` zu Gramm, für `.milliliter` wird `quantity * densityGramsPerMl` zu Gramm — danach dieselbe Gramm-Formel. Kein Runden/Truncate hier (siehe Projekt-Konvention: Berechnung bleibt exakt, Truncate passiert erst bei der Anzeige über `DoubleFormatting`, analog `TDEEView.tdee`). `FoodCatalogItem.supports(_:)` ist ein Dreizeiler-`switch` auf `unit`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NutritionCalculationsTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppCore/Nutrition/NutritionCalculations.swift Sources/FitnessAppCore/Nutrition/FoodUnit.swift Sources/FitnessAppCore/Nutrition/NutrientValues.swift Tests/FitnessAppCoreTests/NutritionCalculationsTests.swift
git commit -m "feat: add quantity-aware nutrient calculation (Core)"
```

---

### Task 3: Persistierter Katalog + Seeder (Data)

**Files:**
- Create: `Sources/FitnessAppData/FoodCatalogEntry.swift`
- Create: `Sources/FitnessAppData/FoodCatalogSeeder.swift`
- Modify: `Sources/FitnessAppData/AppSchema.swift`
- Test: `Tests/FitnessAppDataTests/FoodCatalogSeederTests.swift`

**Interfaces:**
- Consumes: `FoodCatalogItem`, `FoodCatalogData` (Task 1).
- Produces: `@Model public final class FoodCatalogEntry` mit `catalogID: String` (== `FoodCatalogItem.id`), identischen Nährwert-/Einheiten-Feldern wie `FoodCatalogItem`, `public init(from item: FoodCatalogItem)`, `public var asCatalogItem: FoodCatalogItem { get }`.
- Produces: `@MainActor public enum FoodCatalogSeeder { @discardableResult public static func seedIfNeeded(in context: ModelContext) -> Bool }`.

- [ ] **Step 1: Write the failing test**

```swift
#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class FoodCatalogSeederTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    override func tearDownWithError() throws { container = nil }
    private var context: ModelContext { container.mainContext }

    func testSeedsAllCatalogItemsOnce() throws {
        let seeded = FoodCatalogSeeder.seedIfNeeded(in: context)
        XCTAssertTrue(seeded)
        let count = try context.fetchCount(FetchDescriptor<FoodCatalogEntry>())
        XCTAssertEqual(count, FoodCatalogData.all.count)
    }

    func testIsIdempotent() throws {
        FoodCatalogSeeder.seedIfNeeded(in: context)
        let secondCall = FoodCatalogSeeder.seedIfNeeded(in: context)
        XCTAssertFalse(secondCall)
        let count = try context.fetchCount(FetchDescriptor<FoodCatalogEntry>())
        XCTAssertEqual(count, FoodCatalogData.all.count, "Zweiter Aufruf darf keine Duplikate einfuegen")
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FoodCatalogSeederTests`
Expected: FAIL

- [ ] **Step 3: Implement `FoodCatalogEntry`, `FoodCatalogSeeder`, `AppSchema.types`-Eintrag**

`FoodCatalogEntry` ist ein 1:1-Spiegel von `FoodCatalogItem` (gleiche Feldnamen, `@Model`-Klasse statt `struct`). `shortcut: kein Backfill fuer spaeter zu FoodCatalogData.all hinzugefuegte Eintraege (anders als LibrarySeeder.swift:82-100) — fuer v1 akzeptabel, da ein kompletter leerer Katalog nur beim allerersten Start vorkommt; sobald nach dem Release ein neuer Katalogeintrag ergaenzt wird, hier denselben Diff-Backfill wie LibrarySeeder nachziehen.` `seedIfNeeded` prüft `fetchCount(FetchDescriptor<FoodCatalogEntry>()) == 0` (identisches Fehlerverhalten wie `LibrarySeeder.seedIfNeeded`: ein Fetch-Fehler zählt NICHT als "leer"). `AppSchema.types` bekommt `FoodCatalogEntry.self` angehängt.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FoodCatalogSeederTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppData/FoodCatalogEntry.swift Sources/FitnessAppData/FoodCatalogSeeder.swift Sources/FitnessAppData/AppSchema.swift Tests/FitnessAppDataTests/FoodCatalogSeederTests.swift
git commit -m "feat: persist food catalog with idempotent seeder (Data)"
```

---

### Task 4: Mahlzeiten-Modelle (Data)

**Files:**
- Create: `Sources/FitnessAppCore/Nutrition/MealType.swift`
- Create: `Sources/FitnessAppData/MealEntry.swift`
- Create: `Sources/FitnessAppData/MealItem.swift`
- Modify: `Sources/FitnessAppData/AppSchema.swift`
- Test: `Tests/FitnessAppDataTests/MealPersistenceTests.swift`

**Interfaces:**
- Consumes: `NutrientValues`, `FoodUnit` (Task 2), `FoodCatalogEntry` (Task 3).
- Produces: `public enum MealType: String, Codable, Sendable, CaseIterable { case breakfast, lunch, dinner, snack }` mit `var localizationKey: String { "nutrition.mealType.\(rawValue).name" }` (Core).
- Produces: `@Model public final class MealEntry` mit `date: Date`, `mealTypeRaw: String` (typed accessor `mealType: MealType`), `@Relationship(deleteRule: .cascade, inverse: \MealItem.meal) var items: [MealItem] = []`, `public init(date: Date = Date(), mealType: MealType)`.
- Produces: `@Model public final class MealItem` mit `catalogID: String?`, `nameSnapshot: String`, `quantity: Double`, `unitRaw: String` (typed accessor `unit: FoodUnit`), `kcalSnapshot/proteinGSnapshot/carbsGSnapshot/fatGSnapshot: Double` (typed accessor `nutrientsSnapshot: NutrientValues`), `meal: MealEntry?`, `public init(catalogID: String?, nameSnapshot: String, quantity: Double, unit: FoodUnit, nutrients: NutrientValues, meal: MealEntry? = nil)`.

- [ ] **Step 1: Write the failing test**

```swift
#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealPersistenceTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    override func tearDownWithError() throws { container = nil }
    private var context: ModelContext { container.mainContext }

    func testMultipleMealsOfSameTypeSameDayAreAllowed() throws {
        let day = Date()
        context.insert(MealEntry(date: day, mealType: .snack))
        context.insert(MealEntry(date: day, mealType: .snack))
        try context.save()
        let count = try context.fetchCount(FetchDescriptor<MealEntry>())
        XCTAssertEqual(count, 2)
    }

    func testDeletingMealCascadesToItems() throws {
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        let item = MealItem(catalogID: "x", nameSnapshot: "Testfood", quantity: 100, unit: .gram,
                             nutrients: NutrientValues(kcal: 100, proteinG: 1, carbsG: 1, fatG: 1), meal: meal)
        context.insert(item)
        try context.save()
        context.delete(meal)
        try context.save()
        let remaining = try context.fetchCount(FetchDescriptor<MealItem>())
        XCTAssertEqual(remaining, 0)
    }

    func testSnapshotSurvivesCatalogEntryMutation() throws {
        let entry = FoodCatalogEntry(from: FoodCatalogData.all[0])
        context.insert(entry)
        try context.save()

        let nutrients = NutritionCalculations.nutrients(for: entry.asCatalogItem, quantity: 150, unit: .gram)!
        let meal = MealEntry(date: Date(), mealType: .breakfast)
        context.insert(meal)
        let item = MealItem(catalogID: entry.catalogID, nameSnapshot: "Snapshot-Name",
                             quantity: 150, unit: .gram, nutrients: nutrients, meal: meal)
        context.insert(item)
        try context.save()

        // Katalogeintrag aendert sich NACH dem Speichern.
        entry.kcalPer100g = 9999
        try context.save()

        XCTAssertEqual(item.nutrientsSnapshot.kcal, nutrients.kcal, "Snapshot darf sich nicht rueckwirkend aendern")
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MealPersistenceTests`
Expected: FAIL

- [ ] **Step 3: Implement `MealType`, `MealEntry`, `MealItem`, `AppSchema.types`-Einträge**

Relationship-Syntax identisch zu `TrainingPlan.days`/`TrainingDay.exercises`: Cascade-Attribut nur auf der Eltern-Seite (`MealEntry.items`), Kind trägt nur ein plaines `public var meal: MealEntry?`. `catalogID` bewusst `String?`-Scalar, KEIN `@Relationship` — exakt die `ExerciseTemplate.id`-Begründung (Löschen/Ändern des Katalogeintrags darf historische `MealItem`s nie mitreißen). `AppSchema.types` bekommt `MealEntry.self, MealItem.self` angehängt.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MealPersistenceTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppCore/Nutrition/MealType.swift Sources/FitnessAppData/MealEntry.swift Sources/FitnessAppData/MealItem.swift Sources/FitnessAppData/AppSchema.swift Tests/FitnessAppDataTests/MealPersistenceTests.swift
git commit -m "feat: add MealEntry/MealItem models with frozen nutrient snapshots (Data)"
```

---

### Task 5: Tagesziele — Profilfelder + Settings-UI

**Files:**
- Modify: `Sources/FitnessAppData/UserBodyProfile.swift`
- Create: `Sources/FitnessAppUI/Nutrition/NutritionGoalsView.swift`
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: `Tests/FitnessAppDataTests/UserBodyProfileNutritionGoalsTests.swift`

**Interfaces:**
- Consumes: `TDEEView`'s bestehende BMR/TDEE-Berechnung (`BodyCalculations.bmrMifflinStJeor` + `BodyCalculations.tdee`, Core — bereits vorhanden, keine Änderung nötig).
- Produces: auf `UserBodyProfile`: `public var dailyCalorieGoalKcal: Int?`, `public var dailyProteinGoalG: Double?`, `public var dailyCarbGoalG: Double?`, `public var dailyFatGoalG: Double?` — alle optional, Default `nil`, kein Konstruktor-Parameter nötig (reine Lightweight-Migration, Default-Literal reicht wie bei `goalWeightKg`).
- Produces: `NutritionGoalsView` — einfache Form mit 4 optionalen Zahlenfeldern + einem Button "Aus TDEE übernehmen", der den aktuell in `TDEEView` sichtbaren `tdee`-Wert einmalig in `dailyCalorieGoalKcal` kopiert (kein Live-Binding).

- [ ] **Step 1: Write the failing test**

```swift
#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class UserBodyProfileNutritionGoalsTests: XCTestCase {
    func testGoalsDefaultToNilForExistingProfiles() throws {
        let schema = Schema(AppSchema.types)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let profile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        container.mainContext.insert(profile)
        try container.mainContext.save()

        XCTAssertNil(profile.dailyCalorieGoalKcal)
        XCTAssertNil(profile.dailyProteinGoalG)
        XCTAssertNil(profile.dailyCarbGoalG)
        XCTAssertNil(profile.dailyFatGoalG)
    }

    func testGoalsAreIndependentlySettable() {
        let profile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        profile.dailyCalorieGoalKcal = 2200
        XCTAssertEqual(profile.dailyCalorieGoalKcal, 2200)
        XCTAssertNil(profile.dailyProteinGoalG, "Setzen eines Ziels darf andere nicht beeinflussen")
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter UserBodyProfileNutritionGoalsTests`
Expected: FAIL

- [ ] **Step 3: Implement Profilfelder + `NutritionGoalsView`**

Vier neue `public var ... : Int?`/`Double?`-Felder direkt auf `UserBodyProfile` anhängen (gleiche Stelle wie die übrigen optionalen Ziel-Felder, Nähe zu `goalWeightKg`), kein Dictionary/Blob — Projekt-Konvention "flaches Feld pro Wert". `NutritionGoalsView` folgt dem `TDEEView`/`WaterTrackerView`-Baustein-Muster (`DeltiqHeader`, `DeltiqSection`, `DeltiqRow`/`DeltiqControlRow`, `.deltiqScreen()`); "Aus TDEE übernehmen" ruft dieselbe `BodyCalculations`-Formel wie `TDEEView` mit dem dort editierten Gewicht/Aktivitätslevel auf und schreibt `Int(tdee.rounded())` einmalig in `dailyCalorieGoalKcal` — kein neues gemeinsames ViewModel nötig, reiner Funktionsaufruf.

Neue xcstrings-Keys (DE/EN/TR): `nutrition.goals.title`, `nutrition.goals.calorie.label`, `nutrition.goals.protein.label`, `nutrition.goals.carbs.label`, `nutrition.goals.fat.label`, `nutrition.goals.adoptFromTDEE.button`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter UserBodyProfileNutritionGoalsTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppData/UserBodyProfile.swift Sources/FitnessAppUI/Nutrition/NutritionGoalsView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests/FitnessAppDataTests/UserBodyProfileNutritionGoalsTests.swift
git commit -m "feat: add optional daily nutrition goals + settings screen"
```

---

### Task 6: Mahlzeiten-Erfassung — neu, mit Vorschau

**Files:**
- Create: `Sources/FitnessAppUI/Nutrition/MealDraft.swift`
- Create: `Sources/FitnessAppUI/Nutrition/AddMealView.swift`
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: `Tests/FitnessAppUITests/MealDraftTests.swift`

**Interfaces:**
- Consumes: `FoodCatalogEntry` (Task 3), `MealEntry`/`MealItem` (Task 4), `NutritionCalculations.nutrients(for:quantity:unit:)` (Task 2).
- Produces: `@MainActor public final class MealDraft: ObservableObject` mit `date: Date`, `mealType: MealType`, `@Published public private(set) var items: [MealDraft.Item] = []`, `@Published public private(set) var didSaveSuccessfully: Bool = false`.
- Produces: `MealDraft.Item` (nested struct: `catalogID: String?`, `nameSnapshot: String`, `quantity: Double`, `unit: FoodUnit`, `nutrients: NutrientValues`).
- Produces: `MealDraft.addItem(catalogID: String?, nameSnapshot: String, quantity: Double, unit: FoodUnit, nutrients: NutrientValues)` — hängt ein `Item` an `items` an.
- Produces: `var totalPreview: NutrientValues { NutrientValues.sum(items.map(\.nutrients)) }` — rein lesend, berührt nie einen `ModelContext` (das IST die "Vorschau erzeugt keine gespeicherte Mahlzeit"-Garantie: es gibt schlicht keinen Code-Pfad von `totalPreview`/`addItem` zu SwiftData).
- Produces: `func save(into context: ModelContext, persist: (ModelContext) throws -> Void = { try $0.save() }) -> Result<Void, Error>`. No-op (`.success`) ohne jede Context-Berührung, wenn `didSaveSuccessfully` bereits `true` ist — das ist der Doppeltap-Schutz, unabhängig von jedem UI-Button-Zustand. Sonst: `MealEntry` + `MealItem`s einfügen, `persist(context)` aufrufen; bei Erfolg `didSaveSuccessfully = true`; bei Fehler die eingefügten Objekte wieder per `context.delete` entfernen, `items`/`didSaveSuccessfully` unverändert lassen, den Fehler als `.failure` zurückgeben.
- Produces: `AddMealView` — Sheet mit Datum/Typ-Picker, lokaler `FoodCatalogEntry`-Live-Suche (`@Query` + In-Memory-Filtern über den aufgelösten Namen, analog zu bestehenden Picker-Sheets), Mengen-/Einheiten-Eingabe pro Position (nur über `FoodCatalogItem.supports(_:)` erlaubte `FoodUnit`-Fälle), Vorschau-Summe über `totalPreview`, "Speichern"-Button mit `.disabled(draft.didSaveSuccessfully)`, "Abbrechen" verwirft `MealDraft` kommentarlos (kein `save()`-Aufruf, keine Spur im Context).

- [ ] **Step 1: Write the failing test**

```swift
#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealDraftTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private var context: ModelContext { container.mainContext }

    func testPreviewSumsAllDraftItems() {
        let draft = MealDraft(date: Date(), mealType: .lunch)
        draft.addItem(catalogID: "a", nameSnapshot: "A", quantity: 100, unit: .gram,
                      nutrients: NutrientValues(kcal: 100, proteinG: 10, carbsG: 5, fatG: 2))
        draft.addItem(catalogID: "b", nameSnapshot: "B", quantity: 50, unit: .gram,
                      nutrients: NutrientValues(kcal: 50, proteinG: 2, carbsG: 8, fatG: 1))
        XCTAssertEqual(draft.totalPreview.kcal, 150)
    }

    func testPreviewDoesNotPersistAnything() throws {
        // Spec: "Vorschau erzeugt keine gespeicherte Mahlzeit" — solange
        // save() nicht aufgerufen wird, darf im Context rein gar nichts landen.
        let draft = MealDraft(date: Date(), mealType: .snack)
        draft.addItem(catalogID: nil, nameSnapshot: "X", quantity: 1, unit: .piece, nutrients: .zero)
        XCTAssertEqual(draft.items.count, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 0)
    }

    func testSecondSaveCallIsNoOpAfterFirstSucceeds() throws {
        // Doppeltap-Schutz: zwei aufeinanderfolgende save()-Aufrufe (wie bei
        // zwei schnellen Taps, bevor die UI den Button deaktivieren konnte)
        // duerfen nur EINE MealEntry anlegen.
        let draft = MealDraft(date: Date(), mealType: .dinner)
        draft.addItem(catalogID: nil, nameSnapshot: "X", quantity: 1, unit: .piece, nutrients: .zero)

        _ = draft.save(into: context)
        _ = draft.save(into: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 1)
    }

    func testSaveFailurePreservesDraftAndReportsFailure() throws {
        struct Boom: Error {}
        let draft = MealDraft(date: Date(), mealType: .breakfast)
        draft.addItem(catalogID: nil, nameSnapshot: "X", quantity: 1, unit: .gram, nutrients: .zero)
        let itemCountBefore = draft.items.count

        let result = draft.save(into: context) { _ in throw Boom() }

        switch result {
        case .success: XCTFail("Erwartet: Fehler")
        case .failure: break
        }
        XCTAssertEqual(draft.items.count, itemCountBefore, "Entwurf bleibt nach Fehler erhalten")
        XCTAssertFalse(draft.didSaveSuccessfully)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 0, "Fehlgeschlagener Save darf keine Spur hinterlassen")
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MealDraftTests`
Expected: FAIL

- [ ] **Step 3: Implement `MealDraft`, `AddMealView`**

`MealDraft.save`: wenn `didSaveSuccessfully` bereits `true` ist, sofort `.success(())` zurückgeben, OHNE den Context erneut anzufassen (das ist der vollständige Doppeltap-Schutz, unabhängig vom UI-Button-Zustand). Sonst: EINE `MealEntry` + ihre `MealItem`s aufbauen, `context.insert(meal)` + pro Item `context.insert(item)`, dann `persist(context)` (Default `{ try $0.save() }`). Bei Erfolg `didSaveSuccessfully = true`, `.success(())` zurückgeben. Bei Fehler `context.delete(meal)` (SwiftData kaskadiert die Items mit), `items`/`didSaveSuccessfully` unverändert lassen, `.failure(error)` zurückgeben.

`AddMealView`: `@Query` auf `FoodCatalogEntry`, Textfeld filtert client-seitig per `localizedCaseInsensitiveContains` auf dem aufgelösten `String(localized:)`-Namen (gleiches Live-Filter-Prinzip wie der bestehende Exercise-Picker). Mengen-Eingabe bietet nur die laut `FoodCatalogItem.supports(_:)` (Task 2) zulässigen `FoodUnit`-Fälle an — `Picker` aus `FoodUnit.allCases.filter { entry.asCatalogItem.supports($0) }` gebaut. Beim Hinzufügen einer Position wird `nameSnapshot` sofort über `String(localized: String.LocalizationValue(entry.nameKey), bundle: .module)` aufgelöst (Resolution lebt hier in der UI, da nur `FitnessAppUI` Zugriff auf `Bundle.module`/die xcstrings hat) und zusammen mit dem `NutritionCalculations`-Ergebnis an `draft.addItem` übergeben. Speichern-Button bindet zusätzlich `.disabled(draft.didSaveSuccessfully)` als UI-seitige Absicherung (der eigentliche Schutz sitzt aber in `save()` selbst, siehe oben).

Neue xcstrings-Keys: `nutrition.addMeal.title`, `nutrition.addMeal.searchPlaceholder`, `nutrition.addMeal.save`, `nutrition.addMeal.cancel`, `nutrition.mealType.breakfast.name` / `.lunch.name` / `.dinner.name` / `.snack.name`, `nutrition.unit.gram.label` / `.piece.label` / `.milliliter.label`, plus je ein `nutrition.food.{id}.name`-Key pro Katalogeintrag aus Task 1 (alle ~100, hier erst wirklich benötigt).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MealDraftTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Nutrition/MealDraft.swift Sources/FitnessAppUI/Nutrition/AddMealView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests/FitnessAppUITests/MealDraftTests.swift
git commit -m "feat: add meal capture flow with preview-before-save (UI)"
```

---

### Task 7: Mahlzeit bearbeiten / löschen

**Files:**
- Modify: `Sources/FitnessAppUI/Nutrition/MealDraft.swift`
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift` (wiederverwendet für Edit-Modus)
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: `Tests/FitnessAppUITests/MealDraftEditTests.swift`

**Interfaces:**
- Consumes: `MealEntry`/`MealItem` (Task 4), `MealDraft` (Task 6).
- Produces: `MealDraft.init(editing meal: MealEntry)` — lädt Datum/Typ/Positionen aus einer bestehenden `MealEntry` in einen neuen Entwurf, OHNE die Original-Zeile zu berühren. `MealDraft.save` erkennt per gespeicherter `originalMealID: PersistentIdentifier?` den Edit-Fall und überschreibt die bestehende `MealEntry` atomar (alte `MealItem`s löschen, neue aus dem Entwurf einfügen) statt eine zweite anzulegen.

- [ ] **Step 1: Write the failing test**

```swift
#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealDraftEditTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private var context: ModelContext { container.mainContext }

    func testEditingReplacesItemsWithoutCreatingSecondMeal() throws {
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Alt", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let draft = MealDraft(editing: meal)
        draft.items.removeAll()
        draft.addItem(catalogID: nil, nameSnapshot: "Neu", quantity: 200, unit: .gram, nutrients: .zero)
        let result = draft.save(into: context)

        if case .failure(let error) = result { XCTFail("\(error)") }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 1, "Edit darf keine zweite MealEntry anlegen")
        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.map(\.nameSnapshot), ["Neu"])
    }

    func testCancelingEditLeavesOriginalUntouched() throws {
        let meal = MealEntry(date: Date(), mealType: .dinner)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Original", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let draft = MealDraft(editing: meal)
        draft.addItem(catalogID: nil, nameSnapshot: "Wird verworfen", quantity: 1, unit: .gram, nutrients: .zero)
        // Kein draft.save() — Abbrechen heisst: Entwurf wird einfach nicht gespeichert.

        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.map(\.nameSnapshot), ["Original"], "Unveraenderte Originaldaten trotz Entwurfs-Aenderung")
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MealDraftEditTests`
Expected: FAIL

- [ ] **Step 3: Implement Edit-Pfad in `MealDraft` + `AddMealView`-Wiederverwendung**

`AddMealView` bekommt einen optionalen `editing: MealEntry?`-Parameter; bei Edit wird der Titel/Speichern-Label angepasst (Keys: `nutrition.editMeal.title`, `nutrition.editMeal.save`) und ein Löschen-Button mit Bestätigungsdialog (`.confirmationDialog`, Key `nutrition.editMeal.deleteConfirm`) ergänzt, der `context.delete(meal)` + `try context.save()` ausführt (Cascade entfernt die `MealItem`s, Task 4).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MealDraftEditTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Nutrition/MealDraft.swift Sources/FitnessAppUI/Nutrition/AddMealView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests/FitnessAppUITests/MealDraftEditTests.swift
git commit -m "feat: add meal editing and deletion with confirmation (UI)"
```

---

### Task 8: Tagesübersicht

**Files:**
- Create: `Sources/FitnessAppUI/Nutrition/NutritionDayView.swift`
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: `Tests/FitnessAppUITests/NutritionDayAggregationTests.swift`

**Interfaces:**
- Consumes: `MealEntry`/`MealItem` (Task 4), `NutrientValues.sum` (Task 2), `UserBodyProfile`-Zielfelder (Task 5).
- Produces: eine reine, UI-unabhängige Gruppierungsfunktion `NutritionDayAggregator.grouped(meals: [MealEntry]) -> [MealType: [MealEntry]]` und `NutritionDayAggregator.dailyTotal(meals: [MealEntry]) -> NutrientValues` (als `enum` in `FitnessAppUI/Nutrition/`, da sie nur `MealEntry` aus Data konsumiert, nicht in Core gehört — Data ist bereits eine Abhängigkeit von UI).
- Produces: `NutritionDayView` mit Datumsnavigation, Gruppen-Sektionen pro `MealType`, Tagessumme, Fortschrittsbalken NUR für gesetzte Ziele aus Task 5, Empty State für Tage ohne Einträge.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
final class NutritionDayAggregationTests: XCTestCase {
    func testGroupsByMealType() {
        let breakfast = MealEntry(date: Date(), mealType: .breakfast)
        let lunch1 = MealEntry(date: Date(), mealType: .lunch)
        let lunch2 = MealEntry(date: Date(), mealType: .lunch)
        let grouped = NutritionDayAggregator.grouped(meals: [breakfast, lunch1, lunch2])
        XCTAssertEqual(grouped[.lunch]?.count, 2)
        XCTAssertEqual(grouped[.breakfast]?.count, 1)
    }

    func testDailyTotalSumsAllItemsAcrossMeals() {
        let meal1 = MealEntry(date: Date(), mealType: .breakfast)
        _ = MealItem(catalogID: nil, nameSnapshot: "A", quantity: 1, unit: .gram,
                     nutrients: NutrientValues(kcal: 100, proteinG: 1, carbsG: 1, fatG: 1), meal: meal1)
        let meal2 = MealEntry(date: Date(), mealType: .dinner)
        _ = MealItem(catalogID: nil, nameSnapshot: "B", quantity: 1, unit: .gram,
                     nutrients: NutrientValues(kcal: 50, proteinG: 1, carbsG: 1, fatG: 1), meal: meal2)
        let total = NutritionDayAggregator.dailyTotal(meals: [meal1, meal2])
        XCTAssertEqual(total.kcal, 150)
    }

    func testEmptyDayReturnsZeroTotal() {
        XCTAssertEqual(NutritionDayAggregator.dailyTotal(meals: []), .zero)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NutritionDayAggregationTests`
Expected: FAIL

- [ ] **Step 3: Implement `NutritionDayAggregator`, `NutritionDayView`**

`grouped`/`dailyTotal` sind reine, synchrone Funktionen über bereits geladene `[MealEntry]` (die Caller-Seite liefert sie per `@Query` mit Datums-Filter — gleiches Prinzip wie `WaterTrackerView.todayEntries`, kein `#Predicate` für Tagesgrenzen, siehe dortiger Kommentar zu Calendar.startOfDay-Unzuverlässigkeit). Fortschrittsbalken: `if let goal = profile.dailyCalorieGoalKcal { ProgressView(value: ..., total: Double(goal)) }`, sonst nichts rendern (Spec 7, "Tagesziele").

Neue xcstrings-Keys: `nutrition.day.title`, `nutrition.day.empty.title`, `nutrition.day.empty.message`, `nutrition.day.total.label`, `nutrition.day.addMeal.button`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NutritionDayAggregationTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Nutrition/NutritionDayView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests/FitnessAppUITests/NutritionDayAggregationTests.swift
git commit -m "feat: add daily nutrition overview (UI)"
```

---

### Task 9: Dashboard-Kachel

**Files:**
- Modify: `Sources/FitnessAppCore/Programs/DashboardWidgetType.swift`
- Modify: `Sources/FitnessAppUI/DashboardView.swift`
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: `Tests/FitnessAppCoreTests/DashboardWidgetTypeNutritionTests.swift`

**Interfaces:**
- Consumes: `NutritionDayAggregator` (Task 8), `AddMealView`/`NutritionDayView` (Task 6/8).
- Produces: `DashboardWidgetType.nutrition` (neuer Case, ans Ende angehängt), in `DashboardWidgetType.defaultOrder` aufgenommen (bestimmt NUR den Default für neue `UserBodyProfile`-Zeilen — siehe Global Constraints).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FitnessAppCore

final class DashboardWidgetTypeNutritionTests: XCTestCase {
    func testNutritionCaseExistsAndHasLocalizationKey() {
        XCTAssertEqual(DashboardWidgetType.nutrition.localizationKey, "widget.nutrition.name")
    }

    func testNutritionIsPartOfDefaultOrderForNewInstalls() {
        XCTAssertTrue(DashboardWidgetType.defaultOrder.contains(.nutrition))
    }

    func testExistingUserRawListWithoutNutritionStaysUnaffected() {
        // Simuliert einen Bestandsnutzer: sein gespeichertes Raw-Array enthaelt
        // "nutrition" nicht. Der typed accessor (UserBodyProfile.activeDashboardWidgets,
        // Data-Layer) filtert nur auf bekannte rawValues — hier wird nur geprueft,
        // dass ein Bestands-Array ohne den neuen Case ihn nicht automatisch erhaelt.
        let legacyRaw = ["nextWorkout", "coachingInsight"]
        let decoded = legacyRaw.compactMap { DashboardWidgetType(rawValue: $0) }
        XCTAssertFalse(decoded.contains(.nutrition))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DashboardWidgetTypeNutritionTests`
Expected: FAIL

- [ ] **Step 3: Implement `.nutrition`-Case + Dashboard-Kachel**

`DashboardWidgetType`: `case nutrition` ans Ende der Case-Liste, in `defaultOrder` ans Ende anhängen (Reihenfolge nach `trainingCalendar`, siehe bestehende Liste). `DashboardView`'s `switch widget { ... }` bekommt `case .nutrition: nutritionCard` — der Compiler erzwingt durch den fehlenden `default`-Case, dass dieser Fall ergänzt werden MUSS, sonst schlägt der Build fehl (das ist die eingebaute Absicherung gegen "vergessen"). `nutritionCard` zeigt die Tagessumme (über `NutritionDayAggregator.dailyTotal` für heute) + Button "Mahlzeit hinzufügen" (öffnet `AddMealView` als Sheet) + Tap-Ziel `NutritionDayView` (per `.navigationDestination`, analog `historyCard`/`trophyRoomCard`).

Neue xcstrings-Keys: `widget.nutrition.name`, `nutrition.dashboard.addMeal.button`, `nutrition.dashboard.empty.message`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DashboardWidgetTypeNutritionTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppCore/Programs/DashboardWidgetType.swift Sources/FitnessAppUI/DashboardView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests/FitnessAppCoreTests/DashboardWidgetTypeNutritionTests.swift
git commit -m "feat: add nutrition dashboard tile (additive, opt-in for existing users)"
```

---

### Task 10: Verifikations-Sweep

**Files:** keine neuen/geänderten Quelldateien — reine Prüfung.

**Interfaces:** keine (Abschluss-Task).

- [ ] **Step 1: Komplette Testsuite laufen lassen**

Run: `swift test`
Expected: alle Targets (FitnessAppCore, FitnessAppData, FitnessAppUI) PASS, keine Regression in bestehenden Tests.

- [ ] **Step 2: Build aller Produkt-Targets**

Run: `swift build --product FitnessAppCore && swift build --product FitnessAppData && swift build --product FitnessAppUI`
Expected: erfolgreich, keine Warnungen zu fehlenden `AppSchema.types`-Einträgen oder nicht-exhaustiven Switches.

- [ ] **Step 3: Dead-Key-Check für Localizable.xcstrings**

Run: `python .scripts/dead_catalog_v3.py`
Expected: `UNUSED: 0` (Akzeptanzkriterium des Projekts) — jeder in den Tasks 1–9 hinzugefügte Key wird tatsächlich referenziert.

- [ ] **Step 4: Manuelle Durchsicht gegen die Akzeptanzkriterien (Spec Abschnitt 11, nur "Ernährungserfassung und Daten")**

Jede Checkbox aus Spec Abschnitt 11 "Ernährungserfassung und Daten" (12 Punkte) einzeln gegen die Tasks 1–9 abhaken; keine Checkbox aus "KI und Kompatibilität" ist Teil dieses Plans.

- [ ] **Step 5: Commit (nur falls Step 1–3 Korrekturen nötig machten)**

```bash
git add -A
git commit -m "test: verification sweep for nutrition v1 (build, tests, dead-key check)"
```

Falls Step 1–4 ohne Korrekturen durchlaufen, entfällt dieser Commit (nichts zu committen).
