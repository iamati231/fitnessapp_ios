# Hauptnavigation (5 Tabs) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Hauptnavigation von Dashboard/Plan/Messung/Werkzeuge/Mehr auf Heute/Training/Ernährung/Fortschritt/Mehr umstellen — mit einem eigenen Ernährungs-Tab, der die Ernährungsfunktion unabhängig von der optionalen Dashboard-Kachel immer erreichbar macht.

**Architecture:** `AppTab` bekommt einen neuen `.nutrition`-Fall, `.tools` entfällt. `MainTabView` (`RootView.swift`) bindet den neuen Tab auf `NavigationStack { NutritionDayView() }`, verschiebt `CalculatorsView` von eigener Tab-Wurzel zu einem `NavigationLink` innerhalb von `SettingsView`s bestehender gruppierter Navigation, und aktualisiert den Wassertracker-Deep-Link entsprechend. Die Dashboard-Nutrition-Kachel wechselt von einem eigenen Navigations-Push auf einen Tab-Wechsel.

**Spec:** `docs/superpowers/specs/2026-10-22-main-navigation-design.md`

## Global Constraints

- Keine neuen Statistiken, Rechner oder Coaching-Algorithmen.
- Bestehende Views/Modelle/Berechnungen werden wiederverwendet, nicht dupliziert.
- Keine bestehenden Daten werden gelöscht oder migriert.
- Jedes neue/geänderte sichtbare Label geht über `Localizable.xcstrings` (DE/EN/TR).
- Alle 5 Tabs bleiben auf kleiner Gerätebreite und bei großer Bedienungshilfen-Schrift sichtbar/bedienbar.
- Vor Start: tatsächlichen Stand von `AddMealView.swift`/`NutritionDayView.swift`/`DashboardView.swift` prüfen, falls das parallel laufende Online-Food-Lookup-Teilprojekt diese Dateien bereits verändert hat — keine fremden Änderungen überschreiben.
- Kein Merge nach main, kein Release — jede Task endet mit lokalem Commit, Push nur zu diesem bestehenden Feature-Branch für CI.
- Verifikation ausschließlich über macOS-CI (`swift build`/`swift test` via `apple-ci-comparison.yml`) — keine TestingBot-Gerätetests (explizite Nutzervorgabe).

## Review Focus

- Dashboard-Kachel-Tap muss nach der Umstellung weiterhin zur Ernährungsfunktion führen (jetzt per Tab-Wechsel statt eigenem Stack-Push) — keine Regression für Nutzer mit bereits aktivierter Kachel.
- Wassertracker-Erinnerungs-Deep-Link muss nach Entfernen von `.tools` weiterhin direkt zum Wassertracker durchpushen.
- Laufende Trainingseinheit (`workoutPath`) darf bei Tab-Wechseln über alle 5 Tabs nicht zurückgesetzt werden.
- Große Bedienungshilfen-Schrift bei 5 Tab-Labels — "Fortschritt" ist das längste neue Label, auf kleinster unterstützter iPhone-Breite prüfen.
- DE/EN/TR-Label-Längen für "Ernährung"/"Fortschritt" auf Überlauf prüfen.

---

### Task 1: `AppTab` erweitern, neuer Ernährungs-Tab, Tab-Labels umbenennen

**Files:**
- Modify: `Sources/FitnessAppUI/AppNavigation.swift:57-63` (`AppTab`-Enum)
- Modify: `Sources/FitnessAppUI/RootView.swift:266-360` (`MainTabView`)
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings` (neue/geänderte Tab-Label-Keys)
- Test: `Tests/FitnessAppUITests/` (Erweiterung, Dateiname nach Konvention, z.B. `MainTabViewStructureTests.swift` falls ein Pattern für Tab-Struktur-Tests existiert, sonst neue Datei)

**Interfaces:**
- Produziert (für Task 2/3): `AppTab.nutrition`-Fall, den Task 2 (Dashboard-Kachel) und Task 3 (Wassertracker-Link) konsumieren.

- [ ] **Step 1: Failing Test**

Test, der beweist: `AppTab.allCases`-äquivalente Liste (oder direkte Prüfung der `MainTabView`-Tab-Tags, je nach testbarer Oberfläche) enthält `.nutrition`, enthält NICHT mehr `.tools`. Falls `AppTab` keine sinnvolle Unit-Test-Oberfläche hat (reines UI-Enum ohne Logik), stattdessen einen Kompilier-Test: eine Datei, die `AppTab.nutrition` referenziert, muss kompilieren (Swift-Compiler selbst ist hier der Test — kein künstlicher XCTest nötig, im Report begründen falls so gehandhabt).

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

Run: CI-Lauf (`apple-ci-comparison.yml`).
Expected: FAIL (`.nutrition` existiert noch nicht).

- [ ] **Step 3: Implementieren**

`AppTab` um `case nutrition` erweitern, `case tools` entfernen. In `MainTabView.body`: neuen `NavigationStack { NutritionDayView() }` mit `.tag(AppTab.nutrition)` zwischen Plan- und Messung-Tab einfügen (Reihenfolge: dashboard, plan, nutrition, measurement, settings — entspricht Heute/Training/Ernährung/Fortschritt/Mehr). Tab-Labels umbenennen: `tab.dashboard` → "Heute", `tab.plan` → "Training", `tab.measurement` → "Fortschritt", neuer `tab.nutrition` → "Ernährung" (alle via `Localizable.xcstrings`, DE/EN/TR). Den bisherigen `.tools`-`NavigationStack`-Block (Zeilen ~320-336 in `RootView.swift`, exakte Zeilen nach eigenem Stand prüfen) vollständig entfernen — `CalculatorsView`-Verdrahtung wandert zu Task 3.

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

Run: CI-Lauf, Expected: PASS. Dead-Key-Audit: `python .scripts/dead_catalog_v3.py`, `UNUSED: 0` bestätigen — alte Tab-Label-Keys, die durch die Umbenennung verwaist sein könnten, müssen entweder wiederverwendet oder sauber entfernt werden.

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/AppNavigation.swift Sources/FitnessAppUI/RootView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests
git commit -m "feat: restructure main tabs to Heute/Training/Ernährung/Fortschritt/Mehr"
```

---

### Task 2: Dashboard-Kachel wechselt Tab statt eigenem Stack-Push

**Voraussetzung:** Task 1 abgeschlossen (braucht `AppTab.nutrition`).

**Files:**
- Modify: `Sources/FitnessAppUI/DashboardView.swift:548-588` (`nutritionCard`, exakte Zeilen nach Task 1's Stand prüfen)
- Test: Erweiterung bestehender Dashboard-Tests, falls vorhanden, sonst neue Testdatei in `Tests/FitnessAppUITests/`

**Interfaces:**
- Konsumiert: `AppTab.nutrition` aus Task 1, `AppNavigation.selectedTab` (bestehend).

- [ ] **Step 1: Failing Test**

Test, der beweist: Tap auf die `nutritionCard` setzt `navigation.selectedTab = .nutrition`, pusht NICHTS mehr auf einen Dashboard-eigenen `NavigationPath`/pusht kein zweites `NutritionDayView` innerhalb des Dashboard-Stacks (Regressionstest gegen "keine zweite vollständige Ernährungsverwaltung im Dashboard").

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

Run: CI-Lauf, Expected: FAIL.

- [ ] **Step 3: Implementieren**

In `nutritionCard` (beide Branches, leer und nicht-leer — Zeilen 558 und 588 laut aktuellem Stand) den bestehenden `NavigationLink`/Push auf `NutritionDayView()` durch einen einfachen Tap-Handler ersetzen, der `navigation.selectedTab = .nutrition` setzt (gleiches Zugriffsmuster wie `AppNavigation.returnToDashboard()` an anderer Stelle im Code). Bestehende Kachel-Sichtbarkeits-/Reihenfolge-Präferenzen (`activeDashboardWidgetsRaw`) bleiben unangetastet — nur das Tap-Ziel ändert sich.

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

Run: CI-Lauf, Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/DashboardView.swift Tests
git commit -m "fix: nutrition dashboard card switches tabs instead of pushing a duplicate stack"
```

---

### Task 3: Werkzeuge unter "Mehr", Wassertracker-Deep-Link umstellen

**Voraussetzung:** Task 1 abgeschlossen (braucht entferntes `.tools`).

**Files:**
- Modify: `Sources/FitnessAppUI/Settings/SettingsView.swift:155-195` (`groupNavigationSection`)
- Modify: `Sources/FitnessAppUI/RootView.swift` (`applyPendingRouteIfAny()`, Wassertracker-Deep-Link — exakte Zeilen beim Implementieren nachschlagen, Stand nach Task 1 abweichend von aktuell ~362-370)
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`
- Test: Erweiterung von `Tests/FitnessAppUITests/`

**Interfaces:**
- Konsumiert: `AppTab.settings` (bestehend), `CalculatorsRoute`/`CalculatorsView` (bestehend, unverändert).

- [ ] **Step 1: Failing Test**

Test, der beweist: der Wassertracker-Deep-Link (`.deltiqOpenDashboard`-äquivalenter Mechanismus für den Wassertracker — exakten bestehenden Trigger-Namen nachschlagen) setzt nach der Umstellung `selectedTab = .settings` und einen Pfad, der zu `WaterTrackerView` auflöst — nicht mehr `.tools`.

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

Run: CI-Lauf, Expected: FAIL.

- [ ] **Step 3: Implementieren**

Neuer 5. `NavigationLink` in `SettingsView.groupNavigationSection` (gleiches `DeltiqRow`-Muster wie die bestehenden 4) zu `CalculatorsView`, mit `.navigationDestination(for: CalculatorsRoute.self)` innerhalb desselben `NavigationStack` wie die anderen Settings-Links (nicht als eigener `NavigationStack` wie bisher — `CalculatorsView` wird jetzt EINE Ebene tiefer gehängt). `RootView.applyPendingRouteIfAny()` entsprechend umstellen: `selectedTab = .settings`, Pfad-Push auf den neuen, eine Ebene tieferen Wassertracker-Pfad (exakter Mechanismus hängt davon ab, ob `SettingsView` einen eigenen `NavigationPath` bekommt oder `AppNavigation` dafür erweitert wird — Implementierer entscheidet nach bestehendem `toolsPath`-Vorbild, Signatur im Report festhalten).

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

Run: CI-Lauf, Expected: PASS. Dead-Key-Audit erneut: `UNUSED: 0`.

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Settings/SettingsView.swift Sources/FitnessAppUI/RootView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests
git commit -m "feat: move Werkzeuge under Mehr, update water tracker deep link"
```

---

### Task 4: Geräte-/Accessibility-Verifikation der neuen Navigation

**Voraussetzung:** Tasks 1-3 abgeschlossen.

**Files:** Keine Code-Änderungen erwartet — reine Verifikations-Task. Falls dabei echte Abweichungen gefunden werden (z.B. abgeschnittenes Tab-Label), Fix in der betroffenen Datei aus Task 1-3.

- [ ] **Step 1: CI-Lauf über den vollständigen, integrierten Stand**

`gh workflow run apple-ci-comparison.yml --ref <branch>`, `swift build`/`swift test` grün bestätigen.

- [ ] **Step 2: Gezielte Abnahme gegen die Abnahmematrix der Spec/des Referenzplans**

Mindestens NAV01 (5 Tabs in der richtigen Reihenfolge), NAV02 (Ernährung öffnen → Tagesübersicht direkt sichtbar), NAV05 (Werkzeuge/Profil/Einstellungen unter Mehr erreichbar), NAV06 (Dashboard-Kachel führt zum Ernährungs-Tab), NAV08 (laufendes Training + Tab-Wechsel bleibt konsistent) anhand von Code-Review + CI-Build prüfen (kein TestingBot laut Vorgabe) — wo ein echter Gerätenachweis nötig wäre (z.B. visuelles Abschneiden bei großer Schrift), das explizit als nicht verifiziert im Report benennen statt zu behaupten.

- [ ] **Step 3: Bericht**

Kompakte Liste: was verifiziert wurde (mit Methode: Code-Review vs. CI vs. Gerät), was als bewusste Lücke offen bleibt (Fortschritt-Scope-Einschränkung aus der Spec), betroffene Dateien, finaler Commit-Range.
