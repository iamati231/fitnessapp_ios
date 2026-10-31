# Deltiq – Review-Abschluss NUT-01 + OFF-01 (23.10.2026)

**Branch:** `fix/nut01-off01-audit` · **Merge-Basis:** `main` (`5e6ba39`) · **HEAD:** siehe `git log -1`
**CI:** GitHub Actions „Apple CI Vergleichslauf" — **Run 39959799171: alle 17 Steps `success`**
**Status:** Build grün, komplette Suite ausgeführt (1746 Tests), Integritätsprüfung des Speicherns bestanden. P2/P3 unverändert nicht angefasst.

---

## 0. Antwort auf die vier Prüffragen des Reviews

| Frage | Antwort (belegt durch ausgeführten CI-Test) |
|---|---|
| Sind nach fehlgeschlagenem Cleanup alte und neue MealItems gleichzeitig vorhanden? | **Nein.** Die alten `MealItem`-Zeilen werden über ihre `PersistentIdentifier` genau einmal gelöscht und im selben Save committet, bevor die neuen sichtbar „fertig" sind. Der Store enthält danach **nur** die neuen Positionen (Test `testCleanupFailureKeepsCommittedEditAndRetryCleansUpExactlyOnce`, Store-Gegenprobe mit frischem `ModelContext`: `["Neu"]`, genau 1 Zeile). |
| Entspricht `meal.items` danach den dauerhaft gespeicherten Einträgen? | Die gelöschten Objekte sind aus dem Context entfernt und werden **nie mehr berührt** (Zugriff auf eine invalidierte Row ist ein `Fatal error` — genau daran ist die erste Fassung im CI gescheitert). Die Positionen-Ansicht zeigt in diesem Zustand den gespeicherten Stand: gespeicherte neue Positionen aus dem Draft + die alten Positionen aus mitgesicherten **Werten** (`pendingCleanupSummaries`, keine Objekt-Referenz). |
| Kann ein späterer unabhängiger Save Duplikate oder einen abweichenden Zustand persistieren? | **Nein.** Es wird nie etwas neu eingefügt (nur gelöscht), also sind Duplikate strukturell ausgeschlossen; `testEditSaveFailureLeavesNothingBehindForAnUnrelatedLaterSave` prüft genau das inklusive Identität der Originalzeile. |
| Ist ein erneuter Versuch möglich, ohne Einträge zu duplizieren oder zu verlieren? | **Ja.** `save()` behandelt den offenen Cleanup als Aufgabe, nicht als No-Op (`finishPendingCleanup`), der Save-Button bleibt dafür aktiv (`hasPendingCleanup`). Test: zweiter `save()` räumt auf, danach ist die Mahlzeit exakt `["Neu"]`, ein weiteres Speichern ist No-Op. Zusätzlich: `testCleanupCheckpointFailureLeavesStateOpenAndAllowsRetry` deckt den Fall ab, dass auch der CHECKPOINT scheitert. |

**Wichtige Ehrlichkeitsnotiz:** In der Fassung vor diesem Review hätte der Antwortstand „alte UND neue Positionen" gelautet. Ich habe die Lösung deshalb **angepasst**: die alten Positionen werden jetzt nach dem Commit über ihre IDs entfernt und per Cleanup-Save committet; es gibt keinen Zustand mehr, in dem beide dauerhaft im Store stehen.

## 1. Ursachenanalyse NUT-01 (aktualisiert)

1. Original (Audit): Löschen vor dem Save, im Fehlerfall Kopien ohne Save → fremder Save schrieb den Mischstand.
2. Zwischenstand (verworfen, im CI widerlegt): alte Objekte blieben im Context und wurden nach einem Fremd-Commit angefasst → `SwiftData/BackingData.swift:1045: Fatal error: This model instance was invalidated…` (Signal 5 in 4 Tests).
3. **Jetzt:** Reihenfolge *Commit → Checkpoint (kein rollback) → alte IDs einmalig löschen → Cleanup-Save*. Fehler beim Cleanup lässt den Zustand bewusst „offen" (Retry), erzeugt aber nie Duplikate oder Zombies.

## 2. Ursachenanalyse OFF-01 (aktualisiert)

Unverändert: Alles-oder-nichts-Validierung gegen eine Datenquelle, die Unbekannt-Werte ausdrücklich zulässt. Neu abgesichert:
- **Summenregel je Nährstoff unabhängig:** `NutrientValues.sum` wertet jede Dimension separat (`allKnownOrUnknown` je Feld) — Test `testSumWithUnknownValue_isUnknownInDimensionOnly` (Protein unbekannt, Kalorien/Kohlenhydrate bekannt und korrekt summiert).
- **Migration:** additiv `knownNutrientMaskRaw: Int` (Default `0b1111`) auf `FoodCatalogEntry` und `MealItem`; Alt-Zeilen lesen damit „alles bekannt" — geprüft durch die bestehende Suite auf SwiftData (`MealPersistenceTests`, `DataPortabilityRoundtripTests`, 59 Tests) sowie `FoodCatalogEntrySourceTests`.
- **Export/Import alt/neu:** additive Spalte `known_nutrients`; fehlt sie (Alt-Backup), gilt „alle bekannt". `testUnknownNutrientValuesSurviveExportImportRoundtrip` prüft unbekannt → unbekannt (nicht 0) über einen echten ZIP-Roundtrip.
- **Keine stille 0:** Tagessumme, Ziel-Fortschritt (kein Balken), Mahlzeitenzeile, AddMeal-Vorschau, Dashboard-Kachel zeigen „–" (`NutritionDisplay`), Tagesbilanz wird mit `nutrition.day.total.incomplete` als unvollständig erklärt; KI bekommt `unknown` statt 0 und darf daran keine Aussage knüpfen (`testUnknownTotal_isStatedAsUnknownNeverAsZero`, `testFabricatedZeroForUnknownTotal_isRejected`).

## 3. Ausgeführte Tests (echte Ergebnisse)

| Prüfung | Umgebung | Ergebnis |
|---|---|---|
| `swift build` (Debug, ganzes Package) | macOS-Runner, Xcode 26.6, Swift 6.2 | ✅ „Build complete!" |
| `swift test --parallel` (komplette Suite) | dito | ✅ **1746/1746 Tests ausgeführt**, keine Fehler |
| `xcodegen generate` + App/Widget für iOS-Simulator (Debug) | dito | ✅ `** BUILD SUCCEEDED **` |
| App-Build Release + FoundationModels-Weak-Link-Check (I1) | dito | ✅ `** BUILD SUCCEEDED **` |

Relevante Suites (alle grün): `MealDraftEditTests` 8, `MealDraftTests` 6, `NutritionCalculationsTests` 21, `NutritionDayAggregationTests` 6, `OnlineFoodLookupFlowTests` 18, `NutritionInsightGeneratorTests` 22, `DataPortabilityRoundtripTests` 59, `MealPersistenceTests` 3, `AddMealViewDiscardTests` 11.

**Reproduktionsweg für die Integritätsprüfung (so wird sie im Test hergestellt und ist so auf dem Gerät nachstellbar):**
1. Mahlzeit mit einer Position anlegen und speichern.
2. Edit öffnen, Position ersetzen.
3. `draft.save(into:persist:cleanup:checkpoint:)` aufrufen; `cleanup` wirft (Test-Injektion). Auf dem Gerät entspricht das einem fehlschlagenden zweiten `context.save()`.
4. Store mit einem **frischen** `ModelContext(container)` lesen → nur die neue Position, keine Duplikate, `MealEntry` genau 1×.
5. `draft.save(...)` erneut → Cleanup läuft, Zustand unverändert korrekt; weiteres Speichern ist No-Op.

**Nicht ausgeführt / nicht möglich:** Test auf physischem Gerät oder im Simulator (kein Zugriff auf eine macOS-Workstation in dieser Umgebung; die CI baut die App nur). Simulator-/Gerätelauf bleibt als manueller Abnahmeschritt offen — **nicht** als „bestanden" behauptet.

## 4. Geänderte Dateien (Diff gegen `main`)

`Sources/FitnessAppAI/NutritionInsightGenerator.swift`, `Sources/FitnessAppCore/Nutrition/{NutrientValues,FoodCatalogItem,NutritionCalculations}.swift`, `Sources/FitnessAppData/{FoodCatalogEntry,MealItem}.swift`, `Sources/FitnessAppData/Export/{DataExportService,DataImportService}.swift`, `Sources/FitnessAppUI/Nutrition/{MealDraft,AddMealView,NutritionDayView,OnlineFoodCandidatePreviewSheet,NutritionDisplay}.swift`, `Sources/FitnessAppUI/DashboardView.swift`, `Sources/FitnessAppUI/Resources/Localizable.xcstrings` (+5 Keys × DE/EN/TR), Tests: `MealDraftEditTests`, `MealDraftTests`, `NutritionCalculationsTests`, `NutritionDayAggregationTests`, `OnlineFoodLookupFlowTests`, `NutritionInsightGeneratorTests`, `DataPortabilityRoundtripTests`, `MealPersistenceTests`. Doku: `docs/AUDIT_2026-10-23_DELTIQ.md`, `docs/FOLGEAUFTRAG_2026-10-23_ZWISCHENSTAND.md`, diese Datei. Gesamt: 25 Dateien (+2094 / −241 gegen `main`, Doku enthalten).

## 5. Restrisiken

1. **Kein Gerätetest** — SwiftData-Commit-Verhalten auf echtem Store (nicht in-memory) ist über die CI-Laufzeit belegt, aber nicht auf Hardware.
2. `pendingCleanupItemIDs` lebt nur im `MealDraft` (Sheet-Lebensdauer). Wird die App in genau diesem Moment beendet, bleibt die Mahlzeit konsistent (keine Duplikate), der Cleanup ist aber nicht mehr bekannt — die alten Positionen sind dann regulär Teil der Mahlzeit (kein Datenverlust, kein Duplikat).
3. `knownNutrientMaskRaw` ist ein additiv migriertes Feld — auf Gerät nach Update ungeprüft.
4. Downgrade auf eine App-Version ohne die Spalte `known_nutrients` würde fehlende Werte als 0 lesen (bewusst akzeptiert, im Bericht dokumentiert).
5. Zwei im CI beobachtete, **vorbestehende** Warnings (`SessionContentResolver`/`DeloadManager`, Swift-6-Mode) — nicht Teil dieses Auftrags.

## 6. Nächste Schritte (empfohlen)

1. Manueller Geräte-/Simulator-Test der Punkte aus Abschnitt 3 (Schritte 1–5) — einziger offener Abnahmepunkt.
2. PR `fix/nut01-off01-audit` → `main` reviewen und mergen (17/17 CI-Steps grün).
3. Danach wie vereinbart mit P2/P3 beginnen; Reihenfolge unverändert: **SET-01**, **AI-01**, dann **PRIV-01** (Privacy-Manifest) vor jedem App-Store-Schritt.
