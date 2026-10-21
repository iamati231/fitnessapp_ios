# Deltiq Ernährungsassistent — UI-Lücken + lokale KI (Implementierungsplan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die drei offenen UI-Lücken aus dem Review schließen (kompakter, unten verankerter Mengenbereich; Deltiq-Designsystem statt Standard-iOS-Controls; verifiziert locale-reaktive Katalognamen) und darauf aufbauend die optionale, rein lokale KI-Schicht ergänzen (Freitext-Erfassung, Coaching) — ohne die bereits gemergte, auf echtem Gerät verifizierte Basisfunktionalität (Katalog, Erfassung, Tagesübersicht, Dashboard-Kachel, Persistenz) zu verändern oder zu duplizieren.

**Architecture:** Die UI-Lücken betreffen ausschließlich bereits existierende Dateien (`AddMealView.swift`, ggf. `MealDraft.swift`), keine neuen Module. Die KI-Schicht bekommt ein neues, eigenständiges Package-Target `FitnessAppAI`, das Apple Foundation Models kapselt und nur über ein Protokoll mit `FitnessAppUI` verbunden ist — `FitnessAppCore`/`FitnessAppData` erfahren nie etwas von Foundation Models.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, XCTest, Apple Foundation Models (On-Device, iOS 18.2+/kompatibles SDK — Verfügbarkeit vor Task D zwingend gegen aktuelle Apple-Dokumentation prüfen, siehe Task D).

**Quelle:** `C:\Users\a.isik\Downloads\Deltiq_Ernährungsassistent_Implementation_Plan_mit_KI.md` — Abschnitte "UI-Entscheidungen aus dem Review" und Tasks 10–13 (dieser Plan trägt deren Inhalt in TDD-/SDD-taugliche Tasks über). Tasks 1–9 jenes Dokuments sind NICHT Teil dieses Plans — bereits umgesetzt und auf `claude/smart-onboarding-epic` gemergt.

**Bereits vorhanden (nicht anfassen, nur konsumieren):** `FoodCatalogItem`/`FoodCategory`/`FoodCatalogData` (Core), `FoodUnit`/`NutrientValues`/`NutritionCalculations` (Core), `FoodCatalogEntry`/`FoodCatalogSeeder` (Data), `MealType`/`MealEntry`/`MealItem` (Core/Data), `UserBodyProfile`-Zielfelder, `NutritionGoalsView`, `MealDraft`, `AddMealView`, `NutritionDayView`/`NutritionDayAggregator`, `DashboardWidgetType.nutrition`.

## Global Constraints

- App-Mindestziel bleibt iOS 17 / macOS 14. Jede Foundation-Models-Funktion ist strikt optional und zur Laufzeit abgesichert — ohne sie bleiben Suche, manuelle Erfassung, Tagesübersicht und Berechnungen vollständig nutzbar.
- Sprachen: Deutsch, Englisch, Türkisch — jeder neue sichtbare Text geht über `Sources/FitnessAppUI/Resources/Localizable.xcstrings`, nie hartkodiert.
- Rundung/Formatierung: ausschließlich bestehende `Double`-Extensions aus `Sources/FitnessAppCore/Numerics/DoubleFormatting.swift` — keine neue Rundungslogik.
- SwiftData: rein additive `@Model`-Typen, kein `VersionedSchema`/`SchemaMigrationPlan`.
- Bedienelemente für Speichern/Abbrechen/Bearbeiten/Löschen behalten immer einen sichtbaren Text-Label (kein icon-only Control ohne `Text`) — diese Regel hat die Basisfunktionalität bereits zweimal gebrochen (Toolbar-Icon-Kollaps), siehe Review Focus.
- KI ist strikt optional und lokal: kein externer KI-Dienst, kein Cloud-Fallback, keine Netzwerkanforderung. Bei fehlender Verfügbarkeit (Modell/Gerät/OS/Sprache) bleiben manuelle Suche, Erfassung, Übersicht und Berechnungen unverändert verfügbar — keine leere oder blockierte UI.
- KI-Ausgaben sind nie direkt persistiert: KI liefert ausschließlich einen Entwurf (`MealDraft`) zur Prüfung/Bearbeitung; gespeichert wird erst nach ausdrücklicher Bestätigung über den bereits vorhandenen `save()`-Pfad. Katalog und `NutritionCalculations` bleiben einzige Quelle der Nährwerte — die KI erfindet nie einen Nährwert.
- Keine Ernährungsdaten (Lebensmittelnamen, Mengen, Nährwerte) und kein KI-Prompt/keine KI-Antwort in Logs oder Debug-Ausgaben — kein `print`/`debugPrint` auf diesen Werten in neuem Code.
- Kein Merge, kein Release, kein Push als Teil dieses Plans — jede Task endet mit einem lokalen Commit.
- Jede Task, die UI anfasst (A, B, E, F), bekommt am Ende einen echten `swift build`/`swift test`-Lauf auf macOS-CI (GitHub Actions `apple-ci-comparison.yml`, nicht nur `FitnessAppCore` auf Windows) — dieser Branch hat bereits mehrfach gezeigt, dass UI-Probleme (tote Tipp-Bereiche, icon-only Controls) nur auf echtem Gerät/Simulator sichtbar werden, nie im Code-Review.

## Review Focus

- **Toter Tipp-Bereich bei Button+HStack+Spacer-Labels außerhalb von Form/List:** jede neu geschriebene, nicht in einem `Form`/`List` lebende tappbare Zeile mit `Spacer()` im Label braucht `.contentShape(Rectangle())` — dreimal in der Basisfunktionalität vergessen und erst per Gerätetest gefunden (`DashboardView.nutritionCard`, `NutritionDayView.mealEntryRow`).
- **Icon-only Controls in Toolbars:** iOS komprimiert ein `Label(text+icon)`-Toolbar-Item bei Platzmangel neben einem anderen Toolbar-Item stillschweigend auf reines Icon, selbst mit `.labelStyle(.titleAndIcon)` — bereits einmal in dieser Basisfunktionalität passiert (`AddMealView`-Löschen-Button). Jede neue KI-Aktion im Toolbar braucht denselben Check: entweder als eigene Formular-Zeile statt Toolbar-Item, oder nach Implementierung per Gerätetest verifizieren, dass sichtbarer Text bleibt.
- **KI erfindet Nährwerte oder stellt eine unsichere Zuordnung als sicher dar:** ein mehrdeutiger oder nicht zuordenbarer Freitext-Kandidat darf nie automatisch den erstbesten Katalogtreffer übernehmen → Test in Task E.
- **KI-Ausfall blockiert den manuellen Pfad:** jeder KI-Verfügbarkeits-Zustand außer `available` muss den Rest der Erfassung/Übersicht unverändert funktionsfähig lassen → Test in Task D und E.
- **Fehlende Ziele werden von der Coaching-Funktion erfunden:** `nil`-Zielfelder dürfen im Analyse-/Coaching-Text nie als gesetzter Wert erscheinen → Test in Task F.

---

### Task A: Kompakter, unten verankerter Mengenbereich

**Files:**
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift`
- Test: `Tests/FitnessAppUITests/MealDraftTests.swift` (ggf. ergänzen, falls ein neuer `MealDraft`-Zustand nötig wird — siehe Step 3)

**Ausgangslage:** `quantitySection(for:)` ist aktuell eine normale `Section` innerhalb des scrollenden `Form` — Nutzer müssen durch die gesamte (bis zu ~130 Einträge lange) Trefferliste scrollen, um die Menge einzutragen. Im eigenen Gerätetest dieser Session musste die Suche erst auf 0 Treffer gefiltert werden, um den Mengenbereich überhaupt zu erreichen — das ist genau der im Review beschriebene Missstand.

**Interfaces:**
- Konsumiert: `FoodCatalogEntry`, `FoodUnit.supports(_:)` (unverändert).
- Ändert NICHT die Signatur von `MealDraft.addItem`/`save` — reine UI-Umstrukturierung.

- [ ] **Step 1: Verstehen, was fixiert werden muss**

Lies `AddMealView.swift` komplett (413 Zeilen). Die Trefferliste (`searchSection`) bleibt unabhängig scrollbar; `quantitySection(for:)` wird aus dem `Form`-Flow herausgelöst und über `.safeAreaInset(edge: .bottom) { ... }` auf dem `Form` verankert — exaktes Vorbild: `ActiveWorkoutView.swift:197` (`RestTimerBar` als `safeAreaInset`). Zeige den Bereich nur, wenn `selectedEntry != nil` (`if let`), sonst keinen leeren Bereich reservieren.

- [ ] **Step 2: Mengenbereich umbauen**

Verschiebe den Inhalt von `quantitySection(for:)` in eine neue Methode `quantityBottomBar(for entry: FoodCatalogEntry) -> some View`, die KEIN `Section`/`listRowBackground` mehr verwendet (sie lebt jetzt außerhalb des `Form`), sondern ein eigenständiges, über `Color.Deltiq.surface`-Hintergrund + `.deltiqCardStyle()`-ähnliche Abgrenzung sichtbar vom restlichen Screen abgesetztes `VStack` (Name des gewählten Lebensmittels zur Orientierung, Mengenfeld, Einheiten-Picker — siehe Task B für den Picker selbst —, "Hinzufügen"-Button). Binde sie:

```swift
.safeAreaInset(edge: .bottom) {
    if let selectedEntry {
        quantityBottomBar(for: selectedEntry)
    }
}
```

auf das `Form` in `body`. Entferne den `if let selectedEntry { quantitySection(for: selectedEntry) }`-Aufruf aus dem `Form`-Inhalt.

- [ ] **Step 3: Mehrere ausgewählte Positionen erkennbar machen**

`itemsSection` existiert bereits und zeigt jede hinzugefügte Position mit Name/Menge/kcal sowie Swipe-to-Delete (`onDelete`). Das erfüllt "erkennbar, welche Positionen verwaltet werden" bereits — prüfe nur, ob nach `addSelectedEntry()` (die den Bottom-Bar-Zustand zurücksetzt) klar ist, dass die NÄCHSTE Suche eine NEUE Position beginnt, nicht die gerade hinzugefügte editiert. Falls das aus der aktuellen Logik (`selectedEntry = nil` nach `addSelectedEntry()`) nicht schon eindeutig hervorgeht, ergänze keine neue Mehrfach-Auswahl-Logik — das ist außerhalb dieses Tasks (`MealDraft.removeItem` deckt Entfernen bereits ab).

- [ ] **Step 4: Gerätetest (Pflicht, kein Ersatz durch Simulator-Screenshot-Fehlen)**

Baue via `gh workflow run apple-ci-comparison.yml`, warte auf Grün, lade das Simulator-Artefakt, lade es zu TestingBot hoch (Budget vorher prüfen, `max_concurrent=1` beachten) und verifiziere auf einem echten iPhone-15/iOS-18-Simulator:
- Mengenfeld und "Hinzufügen" sind erreichbar, ohne die Trefferliste bis zum Ende zu scrollen.
- Öffnen der Bildschirmtastatur verdeckt weder Mengenfeld noch "Hinzufügen".
- Nach Schließen der Tastatur bleibt der Bereich über dem Home-Indicator/Safe Area sichtbar, nicht dahinter versteckt.

Dokumentiere das Ergebnis (inkl. etwaiger neuer Funde) im Report.

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Nutrition/AddMealView.swift
git commit -m "fix: anchor quantity entry to a bottom-pinned area, independent of search scroll"
```

---

### Task B: Deltiq-Designsystem statt Standard-iOS-Controls

**Files:**
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift`

**Ausgangslage:** `detailsSection` (Mahlzeitentyp) und `quantitySection`/`quantityBottomBar` (Einheit) nutzen aktuell `Picker(...).pickerStyle(.segmented)` — den Standard-iOS-Segmented-Control. Das Deltiq-Designsystem hat dafür bereits einen fertigen Ersatz: `DeltiqSegmentedPicker<Value: Hashable>` (`Theme.swift:818`), bereits verwendet u.a. in `PlateCalculatorView`, `ChartTimeRange`, `OnboardingView`.

**Interfaces:**
- Konsumiert: `DeltiqSegmentedPicker<Value>`, `DeltiqSegmentedOption<Value>` (`Theme.swift`, unverändert, keine neue API nötig).

- [ ] **Step 1: Mahlzeitentyp-Picker ersetzen**

In `detailsSection`: ersetze

```swift
Picker(selection: $draft.mealType) {
    ForEach(MealType.allCases, id: \.self) { type in
        Text(mealTypeLabel(type)).tag(type)
    }
} label: { Text("nutrition.addMeal.mealTypeLabel", bundle: .module) }
.pickerStyle(.segmented)
```

durch

```swift
DeltiqSegmentedPicker(
    options: MealType.allCases.map { DeltiqSegmentedOption($0, label: mealTypeLabel($0)) },
    selection: $draft.mealType
)
```

(gleiches Muster wie ein bestehender Aufrufer, z.B. `ChartTimeRange`-Verwendung in `PlateCalculatorView` — dort exakt nachschauen, falls `DeltiqSegmentedOption`s Reihenfolge/Label-Konvention abweicht).

- [ ] **Step 2: Einheiten-Picker ersetzen**

Im (nach Task A verschobenen) Mengenbereich: ersetze den `Picker(...).pickerStyle(.segmented)` für `selectedUnit` analog durch `DeltiqSegmentedPicker(options: allowedUnits.map { DeltiqSegmentedOption($0, label: unitLabel($0)) }, selection: $selectedUnit)`.

- [ ] **Step 3: Restliche Aktionsbuttons prüfen**

Prüfe `addSelectedEntry`-Button ("Hinzufügen", aktuell `HStack { Spacer(); Text(...); Spacer() }` als Zeilen-Button) und `deleteSection`-Button gegen `Theme.swift`s `DeltiqPrimaryButtonModifier`/`DeltiqSecondaryButtonModifier` (Zeilen 219/248) — falls eine bestehende Deltiq-Button-Komponente exakt diesen Anwendungsfall (voller Breite, zentrierter Text) bereits abdeckt, diese statt der Ad-hoc-`HStack`-Konstruktion verwenden; falls keine passt (z.B. weil sie fest an einen Vollbild-Screen statt an eine Form-Zeile gebunden ist), bei der bestehenden Lösung bleiben und das kurz im Report begründen — kein Fine-Tuning um des Fine-Tunings willen.

- [ ] **Step 4: Bestehende Tests + Gerätetest**

`swift test --filter MealDraftTests` (lokal auf `FitnessAppCore`-Ebene nicht möglich, läuft über macOS-CI) darf nicht regressieren — reine visuelle Änderung, keine Logikänderung erwartet. Gerätetest: Mahlzeitentyp- und Einheiten-Auswahl sehen wie das Deltiq-Orange/Dunkelgrau-Segmented aus (nicht mehr Systemgrau), Verhalten (Auswahl wechselt, Vorschau aktualisiert sich) unverändert.

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Nutrition/AddMealView.swift
git commit -m "fix: use DeltiqSegmentedPicker instead of system segmented control"
```

---

### Task C: Locale-reaktive Katalognamen — verifizieren und absichern

**Files:**
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift` (nur falls Step 1 eine echte Lücke findet)
- Test: `Tests/FitnessAppUITests/FoodCatalogLocalizationTests.swift` (neu)

**Ausgangslage:** Diese App hat KEINEN In-App-Sprachumschalter (geprüft: kein `.environment(\.locale:)`/`AppLanguage`-Mechanismus im Repo) — ein Sprachwechsel läuft ausschließlich über die iOS-Systemeinstellungen (oder die iOS-15+-Pro-App-Sprache), was die App in beiden Fällen neu startet. `resolvedName(for:)` löst `entry.nameKey` bereits bei jedem Rendering über `String(localized:bundle:)` gegen die AKTUELL aktive Locale auf — es gibt also wahrscheinlich keinen echten "Sprache wechselt, View bleibt aber gemountet"-Fall in dieser App. Diese Task verifiziert das, statt blind eine Live-Reaktivität nachzubauen, die es in diesem Produkt vermutlich nie braucht.

- [ ] **Step 1: Verifizieren, ob die Prämisse stimmt**

Grep erneut (nach eigenem Code-Stand) nach `.environment(\.locale` und jedem In-App-Sprachumschalter im gesamten `Sources/`-Baum, nicht nur `FitnessAppUI`. Falls tatsächlich keiner existiert: Ruling — die Live-Reaktivität ist nicht umsetzbar/nicht nötig, dieser Task liefert ausschließlich Tests, die die KORREKTHEIT der Namensauflösung pro Locale beweisen (das eigentliche Risiko: ein falscher/fehlender `nameKey` oder eine falsche Übersetzung, nicht fehlende Reaktivität). Falls doch ein Mechanismus existiert, der `AddMealView` oder `FoodCatalogEntry` ohne Neustart live umschalten könnte: das dann tatsächlich bestehende Reaktivitätsproblem beheben (z.B. `searchText`/`selectedEntry`-State, der an die Locale gebunden neu berechnet werden muss) und diesen Fund im Report explizit benennen, da er von dieser Planannahme abweicht.

- [ ] **Step 2: Test schreiben — Namensauflösung pro Locale**

```swift
import XCTest
@testable import FitnessAppCore
@testable import FitnessAppUI

final class FoodCatalogLocalizationTests: XCTestCase {
    private func resolvedName(_ key: String, locale: Locale) -> String {
        String(localized: String.LocalizationValue(key), locale: locale, bundle: .module)
    }

    func testWaterResolvesPerLocaleIncludingTurkish() throws {
        // Exakten nameKey fuer "Wasser" aus FoodCatalogData.all ermitteln
        // (z.B. per find{ $0.id == "water" } oder analoger Slug) statt zu raten.
        let water = try XCTUnwrap(FoodCatalogData.all.first { $0.id.contains("water") })
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
        // nicht auf den rohen nameKey — Su muss unter Tuerkisch, NICHT unter
        // "water" im Suchfeld auffindbar sein.
        let water = FoodCatalogData.all.first { $0.id.contains("water") }!
        let turkishName = resolvedName(water.nameKey, locale: Locale(identifier: "tr"))
        XCTAssertTrue(turkishName.localizedCaseInsensitiveContains("Su"))
    }
}
```

Exakten `id`/`nameKey` für "Wasser" vorher in `FoodCatalogData.swift` nachschlagen (nicht raten) und den Test entsprechend anpassen, falls der Slug anders lautet.

- [ ] **Step 3: Test laufen lassen**

Run: `swift test --filter FoodCatalogLocalizationTests` (über macOS-CI, nicht Windows — `bundle: .module` für `FitnessAppUI` braucht das echte Ressourcen-Bundle).
Expected: PASS. Ein Fehlschlag hier bedeutet eine ECHTE fehlende/falsche Übersetzung im Katalog — das vor dem Commit beheben (fehlenden xcstrings-Eintrag ergänzen), nicht den Test abschwächen.

- [ ] **Step 4: Commit**

```bash
git add Tests/FitnessAppUITests/FoodCatalogLocalizationTests.swift Sources/FitnessAppUI/Nutrition/AddMealView.swift
git commit -m "test: verify catalog name resolution across de/en/tr locales"
```

---

### Task D: `FitnessAppAI`-Modul und Laufzeit-Verfügbarkeit

**Ziel:** Lokale KI kapseln, ohne `FitnessAppCore`/`FitnessAppData` oder die bestehende manuelle Erfassung von ihr abhängig zu machen.

**Vor Implementierung zwingend (in dieser Reihenfolge):**
1. `Package.swift` und die bestehende Target-Struktur lesen (`FitnessAppCore`/`FitnessAppData`/`FitnessAppHealth`/`FitnessAppActivities`/`FitnessAppUI`) — verstehen, wie ein neues Target eingehängt wird (Produkt-Deklaration, Abhängigkeiten, `App/`-Xcode-Projekt-Einbindung über `project.yml`/XcodeGen).
2. Per `WebSearch`/`WebFetch` die AKTUELLE Apple-Dokumentation zum Foundation-Models-Framework (Namen, Mindest-OS-Version, Verfügbarkeitsprüfung, Sprach-Unterstützung) nachschlagen — NICHT aus Trainingswissen raten, dieses Framework ist neu genug, dass veraltete/erfundene API-Namen ein reales Risiko sind. Konkret klären: wie heißt der Verfügbarkeits-Typ zur Laufzeit, wie wird eine Sitzung/Anfrage gestartet, wie werden strukturierte (typisierte) Ausgaben angefordert, welche Mindestversion/welche Sprachen werden unterstützt.
3. Erst danach die exakten Typnamen/Signaturen für `FitnessAppAI` festlegen.

**Files (Pfade nach Schritt 1 ggf. anpassen):**
- Create: `Sources/FitnessAppAI/NutritionAIAvailability.swift` (oder nach Projektkonvention benannt)
- Create: `Sources/FitnessAppAI/NutritionAIService.swift` (Protokoll + echte Implementierung)
- Modify: `Package.swift`, `project.yml` (neues Target/Produkt)
- Test: `Tests/FitnessAppAITests/NutritionAIAvailabilityTests.swift`

**Interfaces (Mindestanforderung, exakte Namen nach SDK-Recherche):**
- Ein Verfügbarkeitsstatus-Enum mit mindestens den Fällen: verfügbar, Gerät/OS nicht unterstützt, Sprache nicht unterstützt, vorübergehend nicht verfügbar (z.B. Modell lädt/Systemlast) — Namenskonvention wie bestehende Status-Enums im Projekt (siehe `HealthKitError`/`WorkoutWriteAuthorization` als Vorbild für "klare, pattern-matchbare Zustände statt Bool+String").
- Ein Protokoll (z.B. `NutritionAIAvailabilityChecking`) mit einer Methode, die den aktuellen Status liefert — injizierbar, damit Tests und nicht unterstützte Plattformen ohne echtes Foundation-Models-Backend auskommen (Vorbild: `HealthKitController`s injizierbarer `HealthKitService`).
- Foundation-Models-Typen bleiben vollständig innerhalb von `FitnessAppAI` — kein `import FoundationModels` (oder wie das Framework tatsächlich heißt) in `FitnessAppCore`, `FitnessAppData` oder in Dateien außerhalb von `Sources/FitnessAppAI/`.

- [ ] **Step 1: Recherche durchführen und dokumentieren**

Ergebnis der Schritte 1–2 oben als Kommentarblock am Kopf von `NutritionAIAvailability.swift` festhalten (welche SDK-Version/Doku-Stand geprüft wurde, welche Mindestvoraussetzungen gelten) — spätere Leser (und spätere CI-Läufe auf neueren Xcode-Versionen) müssen nachvollziehen können, worauf sich die Implementierung stützt.

- [ ] **Step 2: Failing Test schreiben**

Test für den injizierbaren Verfügbarkeits-Provider: ein Fake/Mock-Provider, der jeden der definierten Zustände zurückgeben kann, plus ein Test, der beweist, dass bei jedem Nicht-`available`-Zustand kein Foundation-Models-Aufruf versucht wird (z.B. über einen Spy, der zählt, ob die zugrunde liegende Anfrage-Methode aufgerufen wurde).

- [ ] **Step 3: Implementieren**

Echte Verfügbarkeitsprüfung gegen die recherchierte API, gated hinter `#if canImport(...)` für das tatsächliche Framework (analog `#if canImport(HealthKit)` in `FitnessAppHealth`) — das Target muss auf macOS/älteren Simulatoren ohne das Framework weiterhin kompilieren.

- [ ] **Step 4: Test laufen lassen, Build aller Targets**

`swift test --filter NutritionAIAvailabilityTests` + `swift build` für das gesamte Package auf macOS-CI.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: add optional on-device AI capability layer"
```

---

### Task E: KI-gestützte Freitext-Erfassung als Entwurf

**Ziel:** Eingaben wie „200 g Hähnchen und 150 g gekochter Reis zum Mittagessen" lokal in strukturierte, überprüfbare Kandidaten umwandeln, die der Nutzer vor dem Speichern sieht und korrigieren kann.

**Voraussetzung:** Task D abgeschlossen und gemerged in diesen Task-Branch/diese Commit-Historie.

**Files (nach Repo-Stand konkretisieren):**
- Create: `Sources/FitnessAppAI/MealTextExtractor.swift` (oder analog benannt) — nimmt Freitext + den lokalen Katalog entgegen, liefert typisierte Kandidaten (Lebensmitteltext, erkannte Menge/Einheit, vermuteter `MealType`, Konfidenz/Mehrdeutigkeits-Flag), ruft dafür Foundation Models auf.
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift` — neue, klar beschriftete KI-Eingabeaktion (sichtbarer Text-Label, siehe Review Focus); bei `.unavailable`-Status zeigt die Aktion stattdessen einen kurzen, lokalisierten Hinweistext plus sichtbarer Verweis auf die normale Suche (kein Ausblenden, kein leerer Zustand).
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: Extraktions-Logik, Zuordnungs-Mehrdeutigkeit, Rückfrage-Pfad, Fehlerfälle (ungültige/unvollständige Modellantwort).

**Verbindlich:**
- Die KI erzeugt NIE einen Nährwert selbst — jeder Kandidat wird gegen `FoodCatalogEntry`/`FoodCatalogItem` abgeglichen, der tatsächliche Nährwert kommt ausschließlich aus `NutritionCalculations.nutrients(for:quantity:unit:)` (Task 2, bestehend). Ein Kandidat ohne eindeutigen Katalogtreffer wird NIE automatisch übernommen — stattdessen manuelle Auswahl aus den Top-Treffern anbieten oder (bei fehlender Menge/unklarer Zubereitung) eine verständliche Rückfrage zeigen.
- Das Ergebnis landet ausschließlich im bestehenden `MealDraft` über `addItem(...)` — kein neuer, paralleler Persistenz-Pfad. Vorschau/Bestätigen/Abbrechen-Verhalten (Task 6, bestehend) bleibt unverändert die einzige Quelle der Wahrheit dafür, ob und wann gespeichert wird.
- Der in Task A gebaute, unten verankerte Mengenbereich bleibt für die manuelle Korrektur eines KI-Kandidaten nutzbar — die KI-Funktion ersetzt ihn nie, sie befüllt höchstens den Entwurf vor.

- [ ] **Step 1: Failing Tests für die Extraktions-Logik**

Mindestens: gültige vollständige Eingabe → genau ein Entwurfs-Kandidat pro genanntem Lebensmittel, keine Persistenz; fehlende Menge → Rückfrage-Zustand, kein stiller Default; mehrdeutiger Katalogtreffer (z.B. "Reis" trifft auf mehrere Reis-Varianten im Katalog) → manuelle Auswahl angeboten, kein automatischer erstbester Treffer; eine absichtlich kaputte/unvollständige simulierte Modellantwort → sicher abgefangen, keine Absturz-/Force-Unwrap-Stelle.

- [ ] **Step 2: Implementieren**

Extraktion über das recherchierte Foundation-Models-API (Task D) mit strukturierter/typisierter Ausgabe (nicht freies Text-Parsing per Regex) — Katalogabgleich per Namens-/Synonym-Vergleich gegen die bereits lokalisierten Katalognamen (wiederverwenden: `resolvedName`-Äquivalent aus `AddMealView`, ggf. in eine gemeinsam nutzbare Funktion extrahieren statt zu duplizieren).

- [ ] **Step 3: UI-Integration**

Eine Aktion in `AddMealView` (sichtbarer Text, z.B. neben/statt dem Suchfeld), die bei `.available` ein Eingabefeld für Freitext zeigt und bei Bestätigung die erkannten Kandidaten in eine bearbeitbare Vorschau überführt (bestehende `itemsSection`/`quantityBottomBar` aus Task A wiederverwenden, nicht duplizieren). Lade-Zustand während der Extraktion sichtbar und lokalisiert. Bei `.unavailable` jeder Ausprägung: lokalisierter Hinweistext statt der Aktion, manuelle Suche bleibt wie gehabt sichtbar und bedienbar.

- [ ] **Step 4: Gerätetest**

Wie Task A Step 4 — zusätzlich: KI-Pfad mit mindestens einer realistischen Eingabe auf einem Gerät/Simulator durchspielen, falls Foundation Models dort überhaupt verfügbar ist (TestingBot-Simulatoren unterstützen on-device-KI-Frameworks möglicherweise nicht — falls nicht verfügbar, den `.unavailable`-Pfad stattdessen verifizieren und das im Report explizit festhalten, keine Verfügbarkeit vortäuschen).

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: add local AI-assisted meal draft parsing"
```

---

### Task F: Lokale Ernährungsanalyse und Coaching

**Ziel:** Optionale lokale Analyse der bestätigten Tagesdaten gegen vorhandene Ziele; allgemeine, nicht-medizinische Hinweise. Keine Diagnosen, keine Behandlungsempfehlungen.

**Voraussetzung:** Task D abgeschlossen.

**Files (nach Repo-Stand konkretisieren):**
- Create: `Sources/FitnessAppAI/NutritionInsightGenerator.swift` (oder analog) — nimmt `NutrientValues` (Tagessumme, aus `NutritionDayAggregator`, bestehend) + optionale Zielwerte (`UserBodyProfile`, bestehend) entgegen, liefert lokalisierten, als KI-generiert gekennzeichneten Text.
- Modify: `Sources/FitnessAppUI/Nutrition/NutritionDayView.swift` — optionaler Analyse-/Coaching-Abschnitt, nur sichtbar wenn KI verfügbar UND mindestens eine Mahlzeit für den Tag existiert.
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: fehlende Ziele werden nie als gesetzt dargestellt; Analyse-Text basiert nachweislich auf den übergebenen deterministischen Werten (kein eigenständiges Neuberechnen); KI-Ausfall lässt die normale Tagesübersicht unverändert.

**Verbindlich:**
- Tageswerte (`NutritionDayAggregator.dailyTotal`) und gespeicherte `MealItem`-Snapshots sind die einzige Faktenquelle — die KI fasst sie zusammen, berechnet nie selbst nach.
- Nur tatsächlich gesetzte Ziele (`UserBodyProfile.dailyCalorieGoalKcal` etc., alle optional) einbeziehen — ein `nil`-Ziel wird nie erfunden oder als "nicht erreicht" dargestellt.
- Jeder KI-generierte Text trägt eine sichtbare, lokalisierte Kennzeichnung ("von der KI erstellt, keine medizinische Beratung" o.ä.) — kein unmarkierter KI-Text neben den deterministischen Zahlen.
- Minimaler Kontext an das Modell: nur die für DIESE Analyse nötigen Werte (Tagessumme, gesetzte Ziele), keine komplette Historie, kein Prompt-/Antwort-Logging.

- [ ] **Step 1: Failing Tests**

Mock-Provider liefert eine kontrollierte Antwort; Test beweist, dass bei `dailyCalorieGoalKcal == nil` der generierte Prompt/Kontext dieses Ziel nicht als Zahl enthält (sondern als "nicht gesetzt" markiert) und der Analyse-Text keine erfundene Zielzahl zeigt. Test beweist, dass bei KI-`.unavailable` kein Analyse-Abschnitt gerendert wird, aber `NutritionDayView`s bestehende Inhalte (Summe, Mahlzeiten-Liste) unverändert bleiben.

- [ ] **Step 2: Implementieren**

`NutritionInsightGenerator` nimmt bereits berechnete `NutrientValues` + optionale Zielwerte als Parameter entgegen (kein eigener SwiftData-Zugriff, reine Funktion über übergebene Werte — Testbarkeit ohne Model-Container). UI-Abschnitt in `NutritionDayView` nur bei verfügbarer KI und nicht-leerem Tag.

- [ ] **Step 3: Gerätetest**

Wie Task E Step 4.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: add optional local nutrition insights and coaching"
```

---

### Abschluss: Verifikations-Sweep + finale Branch-Review

Kein eigener Task — läuft über den SDD-Prozess selbst: nach Task F `swift test`/`swift build` für alle Targets auf macOS-CI, `python .scripts/dead_catalog_v3.py` (Erwartung `UNUSED: 0`), dann die finale, unabhängige Whole-Branch-Review (frischer Reviewer, stärkstes verfügbares Modell) gegen Code, Tests, Regressionen, Lokalisierung und Datenschutz (keine Ernährungs-/KI-Daten in Logs). Kein Merge, keine PR, kein Push ohne explizite Freigabe danach.
