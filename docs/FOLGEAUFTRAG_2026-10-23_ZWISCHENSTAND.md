# Folgeauftrag 2026-10-23 – Zwischenstand (NUT-01 + OFF-01)

**Basis:** `docs/AUDIT_2026-10-23_DELTIQ.md` · Branch `abacus/worktree-ed931e7c` · HEAD `5e6ba39` (Arbeitsbaum beim Start sauber)
**Status:** NUT-01 und OFF-01 implementiert, Tests ergänzt. **Keine Tests ausgeführt** (Umgebung ohne macOS/Xcode, siehe unten). P2/P3 bisher nur gelistet, nicht umgesetzt.
**Diese Datei ist ein Zwischenstand** — der vollständige Abschlussbericht (§5 des Auftrags) folgt.

---

## 1. NUT-01 – sicheres Rollback beim Speichern

### Ursache (belegt)
`Sources/FitnessAppUI/Nutrition/MealDraft.swift`, Edit-Pfad von `save(into:persist:)`:
1. alte `MealItem`s wurden **vor** dem Save `context.delete(...)`,
2. im Fehlerfall wurden **Kopien** der alten Werte neu eingefügt und **nirgends gespeichert**.

Der Store behielt damit die alten Zeilen (Löschungen ungespeichert), während `meal.items` im Context schon auf die Kopien zeigte. Der nächste, völlig unabhängige Save (irgendein Screen) schrieb diesen Mischstand mit → doppelte/abweichende Positionen, obwohl die UI „Es wurde nichts geändert" behauptete. Ein `persist` im Fehlerpfad war laut Auftrag ausgeschlossen (würde fremde offene Änderungen mitbestätigen).

### Lösung (Commit-Grenze verschieben, kein Save im Fehlerpfad)
- Nur `meal.date`/`meal.mealType` werden vor dem Save umgeschrieben (reine Attribute, exakt rückrollbar).
- Neue Items werden eingefügt, **alte bleiben unangetastet gespeichert**.
- `persist` = Commit-Grenze. Fehler → neue Items verlassen den Context, Datum/Typ zurück, `meal.items` = exakt der Stand von vorher.
- Erfolg → alte Items werden in einem **eigenen zweiten Save** (`cleanup`-Seam) entfernt. Scheitert nur der, wird der Edit **nicht** zurückgedreht; `didSaveSuccessfully = true` (erneutes Speichern darf nicht duplizieren), `rollbackToOriginalItems` stellt die ursprünglichen Positionen wieder her, Fehler = `MealDraftItemCleanupError` (kein Positionsverlust).
- Neue Signatur: `save(into:persist:cleanup:)` – beide Seams injizierbar, Default `context.save()`.

### Geänderte Dateien
| Datei | Änderung |
|---|---|
| `Sources/FitnessAppUI/Nutrition/MealDraft.swift` | neuer Ablauf, `MealDraftItemCleanupError`, `rollbackToOriginalItems`, Doku |
| `Sources/FitnessAppUI/Nutrition/AddMealView.swift` | Fehlertext unterscheidet Cleanup-Fehler (`nutrition.addMeal.saveFailed.cleanupMessage`) |
| `Tests/FitnessAppUITests/MealDraftEditTests.swift` | 4 neue Tests |

### Neue Tests (nicht ausgeführt)
- `testEditSaveFailureLeavesNothingBehindForAnUnrelatedLaterSave` – nach Fehler + fremdem `context.save()` steht im Store nur das Original (gleiche `persistentModelID`, keine Kopie).
- `testEditSaveFailureDoesNotTouchUnrelatedPendingChanges` – fremde offene Änderung bleibt im Context.
- `testSuccessfulEditPersistsNewItemsAndRemovesOldOnes` – Erfolgsfall alter Ablauf.
- `testEditCleanupFailureRollsBackToOriginalItemsWithoutDataLoss` – Cleanup-Fehler: kein Positionsverlust, zweites `save()` ist No-Op.

### Reproduktion / Integritätsprüfung (vorgesehen, nicht ausgeführt)
1. Mahlzeit mit 2 Positionen anlegen, bearbeiten, Position ändern.
2. `draft.save(into:persist:)` mit `persist: { _ in throw Boom() }` (Test-Seam, entspricht einem SwiftData-Save-Fehler).
3. Danach **irgendeinen** fremden Save auslösen (`context.save()`) und mit einem **zweiten, frischen** `ModelContext(container)` neu lesen.
4. Erwartung: genau die Positionen von vor dem Edit, dieselbe Objektidentität, keine Duplikate, `meal.date`/`mealType` unverändert.

---

## 2. OFF-01 – fehlende Nährwerte sind unbekannt, nicht null

### Ursache (belegt)
`OnlineFoodCandidatePreviewSheet.OnlineFoodImportValues.init?` verlangte **alle vier** Makros → ein OFF-Treffer mit fehlendem Wert (häufig) war eine Sackgasse: „Hinzufügen" dauerhaft deaktiviert, ohne Begründung, ohne Alternativweg. Zusätzlich hätte jede Lockerung ohne Modelländerung aus „unbekannt" eine erfundene `0` gemacht (`?? 0` im Import, `Double`-Snapshots ohne Unterscheidung).

### Lösung (durchgängig „unknown" statt 0)
| Schicht | Änderung |
|---|---|
| Core | neues `KnownValue` (`.known(Double)` / `.unknown`), `NutrientValues` hält vier `KnownValue`; `sum` = unbekannt, sobald **eine** Position unbekannt ist; `partiallyKnown`; `scaled(_:by:)` (0 g ⇒ 0, auch bei unbekanntem Gehalt) |
| Core | `FoodCatalogItem.kcalPer100g…` → `KnownValue`, neuer Konstruktor `nutrientsPer100g:` + `withNutrients(_:)`; Vollständig-Konstruktor unverändert nutzbar |
| Core | `NutrientsImport.value(_:key:bit:mask:)` + `KnownValue.allKnownMask/.mask(...)` für Backup-Zeilen |
| Data | `FoodCatalogEntry`: `knownNutrientMaskRaw` (additiv, Default `0b1111` = alles bekannt), `nutrientsPer100g`; Komfort-Init nimmt `Double?` und speichert `nil` als **unbekannt** |
| Data | `MealItem`: `knownNutrientMaskRaw` (additiv, Default `0b1111`), `nutrientsSnapshot` liest/schreibt die Maske |
| Data | Export/Import: additive Spalte `known_nutrients` in `meal_items.csv` und `custom_food_catalog.csv`; Import ohne Spalte = „alle bekannt" (Alt-Backups korrekt) |
| AI | `NutritionInsightInput.total*` → `Double?`; Prompt schreibt `unknown` statt 0, keine Prozent-/Restzeile für unbekannte Summen; `allowedNumbers` enthält keine 0 für unbekannte Summen; Instruction erklärt „unknown ≠ 0" |
| UI | neu `NutritionDisplay` („–" statt 0); Tageskarte, Ziel-Fortschritt (kein Balken bei unbekannt), Mahlzeitenzeile, AddMeal-Vorschau, Dashboard-Kachel zeigen „–"; Hinweis `nutrition.day.total.incomplete` bei unvollständiger Tagesbilanz |
| UI | Vorschau: fehlende Felder zulässig (mind. **ein** bekannter Wert, Name gesetzt, keine Negativwerte), Footer erklärt den Grund, neuer Button „Stattdessen eigenes Lebensmittel anlegen" (verdrahtet auf vorhandenes `CustomFoodEntrySheet`), VoiceOver sagt „unbekannt" |

### Neue/aktualisierte Tests (nicht ausgeführt)
`NutritionCalculationsTests` (KnownValue, Summe, Skalierung, „keine Unbekannt-Werte im Normalfall"), `NutritionDayAggregationTests` (Tagessumme mit unbekannter Dimension, `hasUnknownNutrients`, Anzeige-Regel), `OnlineFoodLookupFlowTests` (Teilprodukt importierbar + unbekannt gespeichert; ganz ohne Werte nicht bestätigbar; bestehende Negativ-/Leerfall-Tests angepasst), `NutritionInsightGeneratorTests` (unknown im Prompt, erfundene 0 wird verworfen, Instruction), `DataPortabilityRoundtripTests` (unbekannte Werte überleben Export/Import als unbekannt). Drei bestehende Assertions auf `.value` umgestellt.

### Lokalisierung
5 neue Keys × DE/EN/TR (`nutrition.addMeal.saveFailed.cleanupMessage`, `nutrition.day.total.incomplete`, `nutrition.onlineImport.unknown`, `nutrition.onlineImport.incomplete.hint`, `nutrition.onlineImport.createManually`). Katalog: 2523 Keys, DE/EN/TR vollständig, keine leeren Werte.

---

## 3. Prüfungen

**Ausgeführt**
| Prüfung | Ergebnis |
|---|---|
| `git status`/`log`/`rev-parse` zu Beginn | sauber, HEAD `5e6ba39` |
| `python .scripts/dead_catalog_v3.py` | `Total catalog keys: 2523 · Referenced: 2523 · UNUSED: 0` ✅ |
| Katalog-Validierung (Python) | DE/EN/TR je 0 fehlende/leere Werte ✅ |
| Klammer-/String-Balance-Check aller 21 geänderten Swift-Dateien | alle ausgeglichen ✅ |
| Platzhalter-/Arithmetik-Scan auf `KnownValue`-Feldern | keine verbliebene Direktarithmetik ✅ |
| `.xcstrings`-Roundtrip (JSON identisch) | identisch ✅ ; Diff nur +115 Zeilen (keine Umsortierung) |

**Nicht ausführbar**
`swift build`/`swift test`: scheitert an Dateisystemrechten des Arbeitsbaums (`NSCocoaErrorDomain 257`) bzw. an nicht ausführbaren Binaries im Temp-Klon (`Permission denied`) – **Umgebungsfehler, keine Codeaussage**. Ebenso unmöglich: `xcodebuild`, Simulator/Gerät, OFF-Live-Abfrage, Foundation-Models-Lauf.

---

## 4. P2/P3 – Liste (noch nicht umgesetzt)

| ID | Datei/Komponente | Problem | Lösung | Risiko/Aufwand | Produktentscheidung |
|---|---|---|---|---|---|
| **PRIV-01** ⚠️ *Datenschutz/Release* | App + Widget | **kein `PrivacyInfo.xcprivacy`** – Required-Reason-APIs undatenspezifisch nicht deklariert; App-Store-Upload-Risiko | zwei Manifeste, in `project.yml` als Resource, CI-Prüfschritt | niedrig / klein | nein – **vor Release empfohlen** |
| SET-01 | `SetRow`, `SettingsAppExperienceView` | RIR-Hilfetext-Toggle wirkt nur im Plan-Editor; im Training immer sichtbar | `@AppStorage("showRirTooltips")` in `SetRow.rirSliderRow` + Test | niedrig / klein | ja (Wirkung vs. Beschriftung) |
| AI-01 | `AddMealView.aiSection` | 5 KI-Zustände als 2 dargestellt („Gerät nicht verfügbar" auch bei Sprach-/Temp-Fall) | `switch` je Fall + 3 Keys | niedrig / klein | nein |
| NAV-01 | `SettingsView.groupNavigationSection` | Werkzeuge als 3. Zeile zwischen Gruppen statt eigener Bereich | eigene Gruppen-Seite oder ans Ende | mittel / mittel | ja |
| I18N-01 | `Localizable.xcstrings` | TR-Übungsnamen teils englisch (268 Keys en==tr) | kuratierte Liste | niedrig / mittel | teils |
| DATA-01 | `DataImportService.importMeals` | Import erzeugt leere Mahlzeiten | Mahlzeiten ohne Items am Ende entfernen | niedrig / klein | nein |
| DOC-01 | `README.md` | falsche Tabs/Widget-/Textzahl, „keine Mahlzeitenerfassung" | korrigieren | keins / klein | nein |
| AI-02 | `AddMealView.applyAICandidate` | erkannte `mealType` wird nie übernommen | beim ersten Kandidaten setzen | niedrig / klein | ja |
| NUT-02 | `NutritionDayView.mealEntryRow` | keine Mengen in der Zeile | Menge+Einheit ergänzen | niedrig / klein | nein |
| NUT-03 | Nutrition-Views | `"kcal"`/`"g"` hartcodiert, überall 2 Nachkommastellen | Keys oder dokumentieren; kcal ohne Dezimalen | niedrig / klein | nein |
| AI-03 | `NutritionInsightGenerator` | „hard guarantee"-Kommentar überzeichnet die Heuristik | Kommentar präzisieren | keins / klein | nein |
| I18N-02 | Katalog | 140 Keys mit `de == tr` | bewusste Fälle dokumentieren | keins / klein | nein |
| PLAN-01 | `PlanEditorView` | Aktiv-Toggle wirkt global vor dem Speichern | Notiz/Test | niedrig / klein | nein |

---

## 5. Restrisiken
1. **Kein einziger Test wurde ausgeführt** – die Änderungen sind kompiliert-ungeprüft. Erste Aktion auf macOS/CI: `swift build && swift test`.
2. SwiftData-Additivmigration der neuen `Int`-Felder (`knownNutrientMaskRaw`) ist nach Repo-Muster (`sourceRaw`, Build-173-Crash) abgesichert, aber auf Gerät ungeprüft.
3. Cleanup-Fehlerpfad (zweiter Save) ist nur per Injektion testbar; reales SwiftData-Fehlerverhalten ungeprüft.
4. Backup-Kompatibilität: neue Spalte `known_nutrients` ist additiv; Alt-Backups werden als „alle bekannt" gelesen (gewollt), ein **Downgrade** auf eine ältere App-Version ignoriert die Spalte (dann 0 statt unbekannt) – bewusst akzeptiert.
5. UI-Anzeige „–" (Dynamic Type, VoiceOver) nur per Code plausibilisiert, kein Gerätetest.

## 6. Nächste Schritte (priorisiert)
1. `swift build` + vollständige Test-Suite auf macOS/CI ausführen und Fehler beheben.
2. NUT-01/OFF-01 auf Gerät gegenprüfen (Failure-Injection, Flugmodus, Teilprodukt importieren, Tagesbilanz).
3. SET-01 + AI-01 (klein, hohe Wirkung), danach **PRIV-01 vor jedem App-Store-Schritt**.
4. DOC-01/NAV-01/I18N-01 als Produkt-/Doku-Entscheidung bündeln.
