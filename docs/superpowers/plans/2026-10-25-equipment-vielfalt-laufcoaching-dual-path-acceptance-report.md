# Equipment-Vielfalt & Laufcoaching-Dual-Path – Geräteabnahme: Testbericht

Datum: 2026-10-26
Auftrag: `docs/superpowers/plans/2026-10-25-equipment-vielfalt-laufcoaching-dual-path.md`, Task 11
Branch: `claude/ponytail-audit-16a17f`
Getesteter Commit: `d3ed2d50997cddeed7a62fa533c73fe9405ba02b` (Tasks 1–10, alle zuvor einzeln review-abgenommen)
Apple CI zu diesem Commit: **ROT** (Workflow-Run `40295892184`, abgebrochen im `swift test`-Schritt)

## Gesamtergebnis

**Geräteabnahme konnte NICHT durchgeführt werden.** Der Apple-CI-Lauf, der laut Auftrag zuerst ein lauffähiges Simulator-Artefakt liefern sollte, ist bereits im `swift test`-Schritt fehlgeschlagen (`set -o pipefail`, nicht-null Exit-Code) — dadurch wurden die nachgelagerten Schritte (`xcodebuild` für den iOS-Simulator, `FitnessApp-simulator.zip`) nie ausgeführt. Es existiert kein Build-Artefakt, das auf TestingBot hochgeladen werden könnte. Es wurde **keine TestingBot-Appium-Session erstellt** und damit **kein Guthaben verbraucht** (nur zwei kostenlose REST-Abfragen: Account-Status und Geräteliste — beide bestätigen weiterhin 4284s/~71min verfügbares Guthaben, Free-Trial-Plan).

Das ist nicht nichts: Dies ist der **erste Lauf des echten `swift test`** für die gesamte Arbeit dieses Plans — jede der elf Aufgaben wurde bisher ausschließlich über `swift build`/`swift -frontend -parse` plus manuelles Hand-Tracing verifiziert, weil dieses Windows-Worktree `swift test` grundsätzlich nicht ausführen kann. Der Fund unten ist also genau der Fund, für den diese Art von Geräteabnahme existiert — nur auf CI-Ebene statt auf dem Gerät.

## `swift test --parallel`: 2015 Tests, 5 Fehlschläge

Alle 2015 Tests liefen; 5 Testmethoden schlugen fehl, verteilt auf 2 Dateien. **Keiner der 5 Fehlschläge ist ein Produktionscode-Fehler** — beide Ursachen liegen ausschließlich in den Testdateien selbst, unabhängig voneinander in Task 7 und Task 9 eingeführt. Root-Cause-Analyse unten, jeweils durch direktes Lesen des echten, aktuellen Quellcodes bestätigt (nicht nur behauptet).

### Fund 1 (Task 9, `ActivePlanResolverTests.swift`): Test-Fixture kann den behaupteten Zustand nicht erzeugen

Zwei Tests schlagen fehl:
- `test_cardioRelevantPlan_withTwoCardioCoachPlans_bothNilActivatedAt_returnsNil` — erwartet `nil`, bekommt einen echten Plan.
- `test_cardioRelevantPlan_withTwoCardioCoachPlans_oneNilOneDatedActivatedAt_returnsTheDatedOne` — erwartet den explizit datierten Plan (1970 + 3000s), bekommt den vermeintlich "undatierten".

**Ursache:** `TrainingPlan.init` (`Sources/FitnessAppData/TrainingPlan.swift:178-196`, unverändert seit P6.1/P7.3 — bestätigt per `git diff eb5ebd6..HEAD`: **null Zeilen Diff** an dieser Datei über den gesamten Plan hinweg) stamp­t für einen AKTIVEN Plan immer `Date()`, wenn kein `activatedAt` explizit "gewinnt": `self.activatedAt = activatedAt ?? (isActive ? Date() : nil)`. Da der Parameter `activatedAt: Date? = nil` selbst einen Default von `nil` hat, kann Swift zur Laufzeit nicht unterscheiden, ob der Aufrufer `nil` *explizit* übergeben hat oder den Parameter *weggelassen* hat — beide Fälle liefern denselben `nil`-Wert in die Funktion. Für `isActive: true` (fest in `ActivePlanResolverTests.makePlan`, Zeile 39) wird ein explizit übergebenes `nil` deshalb IMMER durch `Date()` ersetzt — der Test kann einen aktiven Plan mit echtem `activatedAt == nil` über diesen Konstruktor schlicht nicht erzeugen, unabhängig davon, was er übergibt.

Das ist beabsichtigtes, dokumentiertes Verhalten von `TrainingPlan.init` (Kommentar Zeile 191-196: "ein neu erzeugter, bereits aktiver Plan wird JETZT aktiviert — kein erfundenes Datum, sondern der tatsaechliche Erzeugungszeitpunkt"), **kein Fehler in `ActivePlanResolver.swift` selbst** (dessen Logik — `compactMap(\.activatedAt).max()`, dann Eindeutigkeits-Check — korrekt auf den tatsächlich übergebenen Daten arbeitet; sie bekommt in diesen zwei Tests einfach andere Daten als das Testdesign annahm). Beide betroffenen "Plaene" bekamen je einen echten, auf die Millisekunde unterschiedlichen `Date()`-Zeitstempel beim Setup — daher ist das Ergebnis nicht einmal zufällig falsch, sondern deterministisch falsch (der zuletzt erzeugte "undatierte" Plan hat strukturell einen *späteren* Zeitstempel als der explizit auf 1970 gesetzte "datierte" Plan und gewinnt deshalb immer).

**Reichweite:** Betrifft nur diese 2 von 7 Tests in `ActivePlanResolverTests.swift` — die anderen 5 (Ein-Plan, ein `.cardioCoach` unter anderen, mehrere Nicht-Cardio-Plaene, zwei `.cardioCoach` mit unterschiedlichem/identischem echten Datum, drei `.cardioCoach` im Gleichstand) verwenden durchgehend bewusst gesetzte, echte Daten oder prüfen einen Pfad, der von diesem Init-Verhalten nicht betroffen ist — sie liefen alle grün (im Log nicht als Fehlschlag aufgeführt). `ActivePlanResolver.swift` selbst wurde in keinem der 5 Fix-Runden von Task 9 verändert (bestätigt: 0 Diff seit Einführung in Commit `13c636f`) — der produktive Resolver-Code ist korrekt für jeden tatsächlich erreichbaren Zustand.

**Produktionsrelevanz:** `activatedAt == nil` auf einem AKTIVEN Plan ist laut Kommentar (`TrainingPlan.swift:48-50`) nur über einen Backup-Import von vor P6.1 erreichbar — also nicht über diesen Konstruktor-Pfad, sondern vermutlich über direkte Property-Zuweisung im Import-Code. `ActivePlanResolver`s eigene Nil-Tie-Behandlung bleibt für DIESEN (seltenen, Legacy-)Fall weiterhin sinnvoll und korrekt — nur das Testfixture kann ihn nicht über den öffentlichen Konstruktor nachstellen.

### Fund 2 (Task 7, `CoachAdjustmentInsertionUITests.swift`): Erklärende Kommentare schlagen die eigenen Negativ-Prüfungen

Drei Tests schlagen fehl, alle mit demselben Muster — eine `XCTAssertFalse`-Prüfung auf "Substring X darf im Quelltext NICHT vorkommen" schlägt fehl, weil X tatsächlich vorkommt, aber **nur innerhalb eines erklärenden Code-Kommentars**, der genau dokumentiert, warum X falsch wäre — nicht im ausführbaren Code:

1. `testAcceptRecomputesEligibleRestDaysFreshInsteadOfTrustingTheStaleAnalysisSnapshot` — prüft, dass `accept()`s Funktionskörper NICHT `analysis.insertableRestDays` enthält. Der Kommentar bei `CoachAdjustmentCardModel.swift:201` lautet wörtlich: "NIEMALS die beim `make`-Zeitpunkt eingefrorene `analysis.insertableRestDays`" — enthält den verbotenen Substring als Teil der Erklärung, WARUM er verboten ist.
2. `testAcceptSelectsRestDaysUsingNewCardioDaysCountForTheEffectiveGoal` — prüft, dass `accept()` NICHT `CardioFeasibilityCalculator.runTypeMix(` enthält (der in Task 7s Fix-Runde korrigierte Bug). Der Kommentar bei `CoachAdjustmentCardModel.swift:204` lautet wörtlich: "Review-Korrektur: NICHT `CardioFeasibilityCalculator.runTypeMix(...).count`" — derselbe Effekt.
3. `testInsertPathRendersArrowWithoutAnOldNameAndWithoutStrikethrough` — prüft, dass der `.noEligibleCardioDay`-Block in `CoachAdjustmentPreviewView.swift` NICHT `.strikethrough()` enthält. Der Kommentar bei Zeile 142 lautet wörtlich: "kein `.strikethrough()`, da kein ..." — derselbe Effekt.

**Bestätigt per direktem Quelltext-Lesen:** in allen drei Fällen ist der tatsächliche, ausführbare Code korrekt (`accept()` ruft `eligibleRestDaysForInsertion(in: plan)` frisch auf und referenziert `self.analysis` nirgends; `insertCount`/`runTypeMix(` existiert nirgends mehr in `accept()`s Code, nur noch als erklärender Kommentar; die einzige echte `.strikethrough()`-Anwendung in `CoachAdjustmentPreviewView.swift` liegt bei Zeile 123, außerhalb des `.noEligibleCardioDay`-Blocks). Alle drei Fixes wurden in früheren Review-Runden (Task 7, zwei Fix-Runden; unabhängige Scoped-Re-Reviews) bereits korrekt als behoben bestätigt — die Bestätigung erfolgte per Hand-Trace/Grep auf diesem Windows-Host, der den brace-balancierten Funktionskörper-Extraktionscode der Tests selbst nie tatsächlich ausgeführt hat. Das ist eine echte, bisher unentdeckte Schwäche der in diesem gesamten Plan verwendeten Substring-Introspektions-Teststrategie: eine Negativ-Prüfung ("Text X darf nicht vorkommen") kann durch einen guten, erklärenden Kommentar unterlaufen werden, der genau den verbotenen Text zitiert, um zu begründen, warum er verboten ist.

**Produktionsrelevanz:** keine. Alle drei geprüften Verhaltensweisen sind im echten Code nachweislich korrekt implementiert.

## Auswirkung auf frühere Task-Abnahmen

Task 7 ("complete, review clean, 0 deferred" laut Ledger) und Task 9 ("complete, review clean, 0 deferred" laut Ledger) enthalten je einen Test, der auf diesem Mac-Runner tatsächlich fehlschlägt — beide Male aus Gründen, die ausschließlich die TESTS selbst betreffen, nicht den production code, den sie prüfen sollen. Die Ledger-Einträge "review clean" bezogen sich korrekt auf die Prüfung der tatsächlichen Implementierungslogik (per Hand-Trace gegen den echten Produktionscode) — das bleibt richtig. Was in keiner Review-Runde aufgefallen ist: ob die Tests selbst beim echten Ausführen tatsächlich grün wären. Das ist exakt die Lücke, die dieser gesamte Validierungsschritt (Task 11) schließen soll.

## Empfehlung

Kein Produktionscode muss geändert werden. Zwei kleine, gut verstandene Testkorrekturen würden den Build wieder grün machen und damit ein echtes Simulator-Artefakt für die eigentliche Geräteabnahme ermöglichen:

1. `ActivePlanResolverTests.swift`: die beiden betroffenen Tests müssen einen echten `activatedAt == nil`-Zustand auf einem aktiven Plan anders erzeugen als über `TrainingPlan.init` mit `isActive: true` — z. B. durch direkte Zuweisung `plan.activatedAt = nil` NACH der Konstruktion (umgeht den `?? Date()`-Fallback, der nur im Initializer greift), oder durch Testen des Legacy-Import-Pfads, der diesen Zustand tatsächlich erzeugt.
2. `CoachAdjustmentInsertionUITests.swift`: die drei betroffenen Negativ-Prüfungen müssen entweder enger gefasst werden (z. B. nur den Code VOR dem ersten `//`-Kommentar derselben Zeile prüfen, oder gezielt nach einem ausführbaren Vorkommen suchen statt nach einem reinen Substring), oder die erklärenden Kommentare müssten umformuliert werden, um den exakten verbotenen Ausdruck nicht wörtlich zu zitieren.

Diese Korrekturen liegen außerhalb des Auftragsumfangs dieser Geräteabnahme (reine Test-und-Bericht-Aufgabe, siehe Auftrag) und wurden hier bewusst NICHT vorgenommen. Nach einer Entscheidung darüber und einem erneuten grünen CI-Lauf kann die eigentliche TestingBot-Geräteabnahme (Equipment-Vielfalt 2a/2b/2c + Regression, Laufcoaching Option A 3a/3b/3c, Option B) nachgeholt werden — das vorhandene TestingBot-Guthaben (4284s/~71min, Free Trial) ist dafür unverändert und ungenutzt verfügbar.

**Kein Merge, kein PR, kein Produktionscode geändert im Rahmen dieser Abnahme.**
