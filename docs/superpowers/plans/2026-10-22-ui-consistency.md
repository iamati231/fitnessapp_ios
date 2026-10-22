# Appweite UI-Konsistenz (Tastaturen, Zurück/Schließen, Speichern) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bestehende Eingabefelder, Zurück-/Schließen-Mechanik und Speichern-Aktionen app-weit auf die bereits etablierten Deltiq-Standards (`Compatibility.swift`-Keyboard-Helfer, `DeltiqHeader`+`.deltiqSwipeBackEnabled()`+`discardChangesConfirmation`, `DeltiqHeader`-Checkmark+echter `modelContext.save()`+Fehlerbehandlung) angleichen — keine neuen Standards, keine neue fachliche Logik.

**Architecture:** Kein neues Design — reine Konvergenz auf drei bereits dokumentierte Referenz-Implementierungen im Repo: `Compatibility.swift` (`.decimalKeyboard()`/`.keyboardDismissToolbar()`), `MeasurementView.swift` (sauberste Referenz für Header+Swipe-Back+Discard-Schutz gleichzeitig) und `DayEditorView.swift`/`AddMealView.swift` (Speicherfehler-Behandlung). Diese Plan-Datei fasst drei bereits durchgeführte, read-only Audits zusammen (Protokolle nicht separat committed, Ergebnisse direkt in die Tasks übernommen).

**Spec:** Kein separates Spec-Dokument — explizite Nutzervorgabe "keine erneute Brainstorming-Runde für bereits vorhandene App-Standards". Diese Plan-Datei selbst dokumentiert die Zielzustände je Kategorie (siehe Audit-Zusammenfassungen in den einzelnen Tasks).

## Global Constraints

- Keine fachliche Trainings- oder Ernährungslogik wird nebenbei verändert — nur Tastatur-/Navigations-/Speichern-Mechanik.
- Gemeinsame Helfer/Komponenten werden wiederverwendet und ggf. konsequenter angewendet, nicht neu erfunden — kein paralleles zweites Designsystem.
- Jedes geänderte sichtbare Label geht über `Localizable.xcstrings` (DE/EN/TR), falls neue Strings nötig sind (z.B. Discard-Bestätigungstexte).
- Bestehende Wertebereiche und fachliche Validierungen bleiben erhalten.
- Bestehende Lösch-/destruktive Aktionen bleiben klar getrennt und beschriftet (App-weite Prüfung ergab bereits 0 Treffer für die bekannte Icon-only-Destruktiv-Anti-Pattern — nicht erneut einführen).
- Kein Merge nach main, kein Release — jede Task endet mit lokalem Commit, Push nur zu diesem bestehenden Feature-Branch für CI.
- Verifikation ausschließlich über macOS-CI (`swift build`/`swift test`) — keine TestingBot-Gerätetests (explizite Nutzervorgabe für diesen gesamten Umsetzungsauftrag).
- **Dateiüberschneidungs-Warnung:** `AddMealView.swift` wird auch vom Online-Food-Lookup-Plan (Tasks 4/5/6) und indirekt vom Navigations-Plan berührt — vor Task 9 dieser Datei den tatsächlichen Git-Stand prüfen, nicht aus diesem Plan-Text den Zeilenstand übernehmen.

## Review Focus

- Task 4 (PlanEditorView-Datenverlust-Fix) ist der einzige echte Bug unter diesen Funden — braucht einen echten Regressionstest (Mutation → Kaltstart-Simulation → Wert noch da), nicht nur Code-Review.
- Nach Task 5 (Speicherfehler-Vereinheitlichung über 8 Dateien): stichprobenartig prüfen, dass kein Editor jetzt einen Fehler zeigt, wo vorher (korrekt) keiner auftrat — das bestehende Verhalten bei Erfolg darf sich nicht ändern, nur das Fehlerverhalten.
- Task 9 (Discard-Bestätigung): `AddMealView`s eigener Cancel-Pfad ist komplex (KI-Entwurf + manuelle Auswahl + Bottom-Bar) — sorgfältig prüfen, dass `isDirty` wirklich alle Entwurfs-Quellen erfasst, nicht nur das einfachste Feld.
- Nach allen Tasks: `python .scripts/dead_catalog_v3.py`, `UNUSED: 0` bestätigen (mehrere Tasks ändern/entfernen Strings).

---

### Task 1: Tastatur-Typ-Korrekturen (Reps-Feld + WorkoutSummaryView-Dezimalfelder)

**Audit-Fund (Keyboard-Kategorie):** `SetRow.repsInput` (`Sources/FitnessAppUI/Workout/SetRow.swift:645-646`) nutzt `.decimalKeyboard()` für ein `Int`-Feld (Reps) — app-weiter Standard für Integer-Felder ist `.keyboardType(.numberPad)` (siehe `NutritionGoalsView`/`CardioGoalEditorView`/`WorkoutSummaryView.repsField` für dasselbe semantische Feld). `WorkoutSummaryView.swift:2422,2451,2476,2491,2509` (Cardio-Distanz/Dauer/Gewicht-Felder) duplizieren manuell einen `#if os(iOS) .keyboardType(...) #endif`-Block statt des gemeinsamen `.decimalKeyboard()`-Helpers aus `Compatibility.swift`.

**Files:**
- Modify: `Sources/FitnessAppUI/Workout/SetRow.swift:645-646`
- Modify: `Sources/FitnessAppUI/Workout/WorkoutSummaryView.swift:2422, 2451, 2476, 2491, 2509`

- [ ] **Step 1: Failing Test (falls eine testbare Oberfläche existiert, sonst Step 3 direkt mit CI-Build-Verifikation)**

Falls `SetRow`/`WorkoutSummaryView` keine Unit-testbare Keyboard-Konfiguration exponieren (reine SwiftUI-View-Modifier, oft nicht introspektierbar), diesen Schritt als manuelle Code-Verifikation im Report dokumentieren statt eines künstlichen XCTest — Begründung im Report festhalten.

- [ ] **Step 2: (nur falls Step 1 einen Test ergab) Test laufen lassen, Fehlschlag bestätigen**

- [ ] **Step 3: Implementieren**

`SetRow.repsInput`: `.decimalKeyboard()` durch `.keyboardType(.numberPad)` ersetzen. `WorkoutSummaryView`s 5 Stellen: den manuell duplizierten `#if os(iOS) .keyboardType(...) #endif`-Block durch den gemeinsamen `.decimalKeyboard()`-Helper aus `Compatibility.swift` ersetzen (gleiche Semantik, weniger Duplikat).

- [ ] **Step 4: CI-Lauf, `swift build`/`swift test` grün bestätigen**

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Workout/SetRow.swift Sources/FitnessAppUI/Workout/WorkoutSummaryView.swift
git commit -m "fix: correct keyboard types for reps/decimal fields in workout views"
```

---

### Task 2: Keyboard-Dismiss nachrüsten (3 Screens)

**Audit-Fund:** `DayEditorView.swift:777-784` (Ausdauer-Distanzfeld), `Sources/FitnessAppUI/Settings/GearListView.swift:325-330` (Gear-Kilometerstand-Editor-Sheet), `Sources/FitnessAppUI/Baseline/BaselineCheckFlowView.swift:1230-1239` (`decimalInputRow`-Helper) haben Dezimalfelder, rufen aber `.keyboardDismissToolbar()` (`Compatibility.swift`) nirgends auf ihrer Root-View auf — Tippen außerhalb des Feldes schließt die Tastatur dort nicht.

**Files:**
- Modify: `Sources/FitnessAppUI/Workout/DayEditorView.swift`
- Modify: `Sources/FitnessAppUI/Settings/GearListView.swift`
- Modify: `Sources/FitnessAppUI/Baseline/BaselineCheckFlowView.swift`

- [ ] **Step 1: Implementieren**

`.keyboardDismissToolbar()` auf die jeweilige Root-View der 3 betroffenen Screens anwenden (gleiche Stelle wie bei den bereits konformen 12 Screens, z.B. `AddMealView`/`NutritionGoalsView` als Vorbild für die Anwendungsstelle).

- [ ] **Step 2: CI-Lauf, grün bestätigen**

- [ ] **Step 3: Commit**

```bash
git add Sources/FitnessAppUI/Workout/DayEditorView.swift Sources/FitnessAppUI/Settings/GearListView.swift Sources/FitnessAppUI/Baseline/BaselineCheckFlowView.swift
git commit -m "fix: add keyboard dismiss toolbar to 3 screens missing it"
```

---

### Task 3: AddMealView-Suchfeld an ExerciseLibraryView-Standard angleichen

**Audit-Fund:** `ExerciseLibraryView.searchField` (`Sources/FitnessAppUI/Settings/ExerciseLibraryView.swift:212-239`) baut bewusst Icon+Clear-Button+`Color.Deltiq.fill`-Hintergrund als einheitlichen `.searchable()`-Ersatz. `AddMealView.searchSection`s Such-TextField (`Sources/FitnessAppUI/Nutrition/AddMealView.swift:172-180`) ist dagegen ein nacktes `TextField` ohne dieses Chrome.

**Voraussetzung:** vor Implementierung den TATSÄCHLICHEN Stand von `AddMealView.swift` prüfen — das Online-Food-Lookup-Plan könnte diese Datei zwischenzeitlich verändert haben (Zeilen 172-180 sind der Stand vor diesem Plan).

**Files:**
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift` (Suchfeld-Bereich, exakte Zeilen nach eigenem Stand prüfen)

- [ ] **Step 1: Implementieren**

Suchfeld in `AddMealView` auf dasselbe Icon+Clear-Button+`Color.Deltiq.fill`-Muster wie `ExerciseLibraryView.searchField` umstellen (Komponente extrahieren und beide Call-Sites darauf umstellen, falls das ohne Risiko für den bestehenden Food-Filter-Code möglich ist — sonst das Muster 1:1 duplizieren wie bisher bei `ExerciseLibraryView` selbst gehandhabt, Implementierer entscheidet nach Aufwand/Risiko und hält die Wahl im Report fest).

- [ ] **Step 2: CI-Lauf, grün bestätigen**

- [ ] **Step 3: Commit**

```bash
git add Sources/FitnessAppUI/Nutrition/AddMealView.swift
git commit -m "fix: align AddMealView search field chrome with ExerciseLibraryView standard"
```

---

### Task 4: PlanEditorView — fehlender `modelContext.save()` (Datenverlust-Bug, hohe Priorität)

**Audit-Fund (KRITISCH, einzige echte Regression derselben bereits gefixten Bugklasse):** `PlanEditorView.swift:677-687`s `saveAction` ruft NUR `dismiss()` auf, KEIN `modelContext.save()` — trotz echter `@Bindable`-Mutationen (Wochen, Zielumgebung, Name, Aktiv-Toggle, Progression-RIR). Identischer Bug wurde in `DayEditorView.swift:337-366` bereits explizit gefixt (Kommentar dort referenziert denselben Fehler) — hier nie nachgezogen. Datenverlust bei Kaltstart kurz nach Edit möglich, da SwiftData `@Bindable`-Mutationen ohne expliziten `save()`-Aufruf nicht garantiert vor App-Terminierung persistiert sind.

**Files:**
- Modify: `Sources/FitnessAppUI/Workout/PlanEditorView.swift:677-687`
- Test: `Tests/FitnessAppUITests/` oder `Tests/FitnessAppDataTests/` (Dateiname nach Konvention — Vorbild: falls ein Test für `DayEditorView`s Fix existiert, dasselbe Muster für `PlanEditorView` übernehmen)

- [ ] **Step 1: Failing Test**

Test, der beweist: eine `@Bindable`-Mutation an `TrainingPlan` (z.B. `plan.weeks`) gefolgt vom `saveAction`-Äquivalent, dann ein frisch aufgebauter `ModelContainer`/`ModelContext` auf demselben Store (simuliert Kaltstart) — die Mutation muss sichtbar sein. Vorher (ohne Fix) muss dieser Test fehlschlagen (Mutation geht verloren, falls nicht explizit gespeichert — ggf. über `modelContext.rollback()` vor dem simulierten Neu-Fetch beweisen, dass ohne `save()` der Wert nicht persistiert war).

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

Run: CI-Lauf. Expected: FAIL.

- [ ] **Step 3: Implementieren**

`saveAction` in `PlanEditorView.swift:677-687` um einen echten `try? modelContext.save()` (oder `do/catch` mit Fehlerbehandlung, konsistent mit Task 5 falls diese Task zuerst läuft) VOR `dismiss()` ergänzen — exaktes Muster von `DayEditorView.swift:337-366` übernehmen (inkl. dortiger Fehlerbehandlung, die bei einem Fehler NICHT dismisst).

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

Run: CI-Lauf. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Workout/PlanEditorView.swift Tests
git commit -m "fix: PlanEditorView now persists edits before dismissing (data-loss bug, same class as DayEditorView fix)"
```

---

### Task 5: Speicherfehler-Behandlung und Doppeltap-Schutz vereinheitlichen (8 Dateien, gleiches Muster)

**Audit-Fund (dominante, wiederkehrende Abweichung):** mehrere Editoren nutzen `try?` ohne Fehlerbehandlung oder rufen `modelContext.save()` gar nicht auf — ein fehlgeschlagener Save sieht für den Nutzer wie Erfolg aus. Referenzmuster: `AddMealView`s `catch { showingSaveError = true }` + `draft.didSaveSuccessfully`-Guard gegen Doppeltap.

Betroffen (alle mit demselben mechanischen Fix — EIN Dispatch für alle, da "gleiche Art von kleiner, unabhängiger Änderung" pro SDD-Konvention):

| Datei | Fehlendes |
|---|---|
| `Sources/FitnessAppUI/Settings/BodyDataEditorView.swift:236-254` | Kein Doppeltap-Schutz; kein explizites `modelContext.save()`/Fehlerbehandlung |
| `Sources/FitnessAppUI/Settings/CardioGoalEditorView.swift:74-82, 170-196` | Kein `isDisabled`-Gate trotz Freitext-Zahlenfeldern; `try? modelContext.save()` verschluckt Fehler |
| `Sources/FitnessAppUI/Settings/PeriodicCheckInView.swift:107-113, 324-390` | Zeigt `didJustSave=true` unconditional direkt nach `insert`, ohne Persistenz-Verifikation; kein Doppeltap-Schutz |
| `Sources/FitnessAppUI/Settings/ExerciseLibraryEditorSheet.swift:78-87, 215-237` | Kein Doppeltap-Schutz; `try? modelContext.save()` verschluckt Fehler |
| `Sources/FitnessAppUI/Settings/GearListView.swift:262-275, 375-396` (`GearEditorView`) | Kein Doppeltap-Schutz; GAR KEIN `modelContext.save()`-Aufruf |
| `Sources/FitnessAppUI/Settings/TrainingLocationEquipmentEditorView.swift:61-73, 181-210` | Kein `modelContext.save()` überhaupt, obwohl ein Folge-Effekt (`applyEquipmentAdaptations`) auf Basis eines unbestätigten Writes ausgelöst wird |
| `Sources/FitnessAppUI/Workout/ExerciseEditorView.swift:90-104, 273-288, 345-363` | Delete-Pfad: `try? modelContext.save()` verschluckt Fehler, `dismiss()` läuft trotzdem |
| `Sources/FitnessAppUI/MeasurementView.swift:979-992, 996-1129, 1139-1140` | Kein Doppeltap-Schutz (Insert-Pfad kann 2× feuern); `try? modelContext.save()` verschluckt Fehler |

**Files:** alle 8 oben gelisteten.

- [ ] **Step 1: Failing Tests**

Mindestens 2 repräsentative Tests (nicht 8 identische — ein Test für "fehlender `modelContext.save()`-Aufruf" z.B. an `GearEditorView`, ein Test für "Doppeltap erzeugt kein Duplikat" z.B. an `MeasurementView`, je mit kurzer Begründung im Report, dass dieselbe Fix-Form auf alle 8 angewendet wurde).

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

- [ ] **Step 3: Implementieren**

Für jede der 8 Dateien, am jeweiligen Save-Call-Site: (a) falls kein `modelContext.save()`-Aufruf existiert, einen echten `do { try modelContext.save() } catch { /* Fehler sichtbar machen, analog AddMealView showingSaveError */ }` ergänzen; (b) `try?` durch `do/catch` mit sichtbarer Fehlermeldung ersetzen, wo bereits ein `try?` existiert; (c) einen `isSaving`/`didSaveSuccessfully`-äquivalenten Guard gegen Doppeltap ergänzen, wo noch keiner existiert; (d) bei `CardioGoalEditorView` zusätzlich ein `isDisabled`-Gate auf dem Save-Checkmark ergänzen (Freitext-Zahlenfelder müssen vor Speichern validiert sein); (e) bei `PeriodicCheckInView` die `didJustSave=true`-Anzeige hinter den tatsächlichen Erfolg des `save()`-Aufrufs verschieben statt direkt nach `insert`.

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Settings/BodyDataEditorView.swift Sources/FitnessAppUI/Settings/CardioGoalEditorView.swift Sources/FitnessAppUI/Settings/PeriodicCheckInView.swift Sources/FitnessAppUI/Settings/ExerciseLibraryEditorSheet.swift Sources/FitnessAppUI/Settings/GearListView.swift Sources/FitnessAppUI/Settings/TrainingLocationEquipmentEditorView.swift Sources/FitnessAppUI/Workout/ExerciseEditorView.swift Sources/FitnessAppUI/MeasurementView.swift Tests
git commit -m "fix: unify save error handling and double-tap protection across 8 editors"
```

---

### Task 6: Swipe-Back nachrüsten (7 Screens)

**Audit-Fund:** 7 Screens verstecken die native Navbar (`DeltiqHeader`-Muster), rufen aber `.deltiqSwipeBackEnabled()` nicht auf — Swipe-Back bleibt tot, nur der Chevron funktioniert.

**Files:**
- Modify: `Sources/FitnessAppUI/Workout/TimedWorkoutPlayerView.swift` (AMRAP-, EMOM-, ForTime-Player — 3 Stellen: ~634-636, ~1265-1267, ~1879-1881)
- Modify: `Sources/FitnessAppUI/Workout/CircuitWorkoutPlayerView.swift:211-213`
- Modify: `Sources/FitnessAppUI/Workout/EnduranceIntervalPlayerView.swift:145-147`
- Modify: `Sources/FitnessAppUI/Workout/FourWeekReviewEntryView.swift:74-128`
- Modify: `Sources/FitnessAppUI/Workout/FourWeekReviewView.swift:75-102`

- [ ] **Step 1: Implementieren**

`.deltiqSwipeBackEnabled()` an allen 7 Stellen ergänzen (gleiche Anwendungsstelle wie bei den ~48 bereits konformen Screens — direkt neben dem bestehenden `.toolbar(.hidden, for: .navigationBar)`/`.navigationBarBackButtonHidden(true)`-Paar).

- [ ] **Step 2: CI-Lauf, grün bestätigen**

- [ ] **Step 3: Commit**

```bash
git add Sources/FitnessAppUI/Workout/TimedWorkoutPlayerView.swift Sources/FitnessAppUI/Workout/CircuitWorkoutPlayerView.swift Sources/FitnessAppUI/Workout/EnduranceIntervalPlayerView.swift Sources/FitnessAppUI/Workout/FourWeekReviewEntryView.swift Sources/FitnessAppUI/Workout/FourWeekReviewView.swift
git commit -m "fix: restore swipe-back gesture on 7 screens hiding the native nav bar"
```

---

### Task 7: Sheets auf DeltiqHeader umstellen (3 Screens)

**Audit-Fund:** `NewCustomExerciseSheet.swift:101-124`, `DayPickerSheet.swift:61-67`, `ProgramTemplatePickerView.swift:63-73` (Picker-Root, nicht `TemplatePreviewView`) nutzen natives `navigationTitle`+Toolbar-Cancel statt `DeltiqHeader`+Chevron+`interactiveDismissDisabled`.

**Files:**
- Modify: `Sources/FitnessAppUI/Workout/NewCustomExerciseSheet.swift`
- Modify: `Sources/FitnessAppUI/Workout/DayPickerSheet.swift`
- Modify: `Sources/FitnessAppUI/Workout/ProgramTemplatePickerView.swift`

- [ ] **Step 1: Implementieren**

Alle 3 auf `DeltiqHeader`+Chevron+`interactiveDismissDisabled`-Muster umstellen, analog zu bereits konformen Sheet-Editoren (`ExerciseEditorView`/`PlanBuilderView` als Vorbild). `NewCustomExerciseSheet`s `isDisabled: trimmedName.isEmpty`-Gate bleibt erhalten, wandert nur in die neue `DeltiqHeaderAction`.

- [ ] **Step 2: CI-Lauf, grün bestätigen**

- [ ] **Step 3: Commit**

```bash
git add Sources/FitnessAppUI/Workout/NewCustomExerciseSheet.swift Sources/FitnessAppUI/Workout/DayPickerSheet.swift Sources/FitnessAppUI/Workout/ProgramTemplatePickerView.swift
git commit -m "fix: align 3 sheets with the DeltiqHeader sheet-dismiss standard"
```

---

### Task 8: Discard-Bestätigung nachrüsten (AddMealView, NewCustomExerciseSheet, BaselineCheckFlowView)

**Audit-Fund:** 3 Screens mit echten Eingabedaten verwerfen beim Schließen kommentarlos, ohne das etablierte `discardChangesConfirmation`+`isDirty`-Muster (Referenz: `MeasurementView`) zu nutzen. `AddMealView.swift:94-103, 98-102`s "Abbrechen" ruft `dismiss()` unbedingt auf, ohne Dirty-Check.

**Voraussetzung:** Task 7 (falls `NewCustomExerciseSheet` dort bereits auf `DeltiqHeader` umgestellt wurde) UND aktueller Stand von `AddMealView.swift` nach dem parallel laufenden Online-Food-Lookup-Plan prüfen — nicht blind von den Audit-Zeilennummern ausgehen.

**Files:**
- Modify: `Sources/FitnessAppUI/Nutrition/AddMealView.swift`
- Modify: `Sources/FitnessAppUI/Workout/NewCustomExerciseSheet.swift`
- Modify: `Sources/FitnessAppUI/Baseline/BaselineCheckFlowView.swift`
- Modify: `Sources/FitnessAppUI/Resources/Localizable.xcstrings` (falls neue Bestätigungstexte nötig — `discardChangesConfirmation` nutzt vermutlich bereits existierende lokalisierte Strings aus `MeasurementView`s Verwendung, prüfen bevor neue angelegt werden)

- [ ] **Step 1: Failing Tests**

Je Screen: mit ungespeicherten Änderungen (z.B. getippter KI-Freitext in `AddMealView`, ausgefüllte Felder in `NewCustomExerciseSheet`, bereits bearbeitete Bewegungsfamilie in `BaselineCheckFlowView`) → Schließen-Aktion zeigt `discardChangesConfirmation`, nicht sofortigen `dismiss()`. Ohne Änderungen → Schließen dismisst direkt ohne Rückfrage (kein unnötiger Dialog).

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

- [ ] **Step 3: Implementieren**

`isDirty`-Berechnung je Screen (für `AddMealView`: muss ALLE Entwurfs-Quellen erfassen — KI-Freitext-Eingabe, ausgewählter manueller Katalog-Eintrag mit Menge in der Bottom-Bar, nicht nur ein einzelnes Feld) + `discardChangesConfirmation(isPresented:onDiscard:)` aus `Theme.swift` am jeweiligen Cancel/Close-Pfad ergänzen, exakt nach `MeasurementView`s Referenzmuster.

- [ ] **Step 4: Tests laufen lassen, Erfolg bestätigen**

- [ ] **Step 5: Commit**

```bash
git add Sources/FitnessAppUI/Nutrition/AddMealView.swift Sources/FitnessAppUI/Workout/NewCustomExerciseSheet.swift Sources/FitnessAppUI/Baseline/BaselineCheckFlowView.swift Sources/FitnessAppUI/Resources/Localizable.xcstrings Tests
git commit -m "fix: add discard-changes confirmation to 3 screens with real draft data"
```

---

### Task 9: Verifikation und Abschlussbericht

**Voraussetzung:** Tasks 1-8 abgeschlossen.

- [ ] **Step 1: CI-Lauf über den vollständigen, integrierten Stand**

- [ ] **Step 2: Dead-Key-Audit**

`python .scripts/dead_catalog_v3.py`, `UNUSED: 0` bestätigen.

- [ ] **Step 3: Bericht**

Kompakte Liste: alle 20 behobenen Abweichungen (aus den 3 Audits) mit Status, die 2 bewusst NICHT behobenen Einzelfälle (OnboardingView strukturelle Eigenständigkeit, ExerciseLibraryView Chevron-als-Close) mit Begründung, betroffene Dateien insgesamt, finale Commit-Range, CI-Nachweis.
