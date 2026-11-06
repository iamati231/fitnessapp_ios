# AI Running Coach – Phase 2 Implementierungsplan

Siehe `docs/superpowers/specs/2026-11-06-ai-running-coach-phase2-design.md`
für Audit-Ergebnis und Designentscheidungen. Dieser Plan ist in die vier
vom Ticket vorgegebenen Arbeitspakete gegliedert; alle vier gehören zu
Phase 2 (Ticket: "nicht nach 2A oder 2B aufhören").

Globale Leitplanken für alle vier Pakete (Ticket Abschnitt "Nicht-Ziele"/
"Verbindliche Einschränkungen"):

* Kein Schreibzugriff auf `TrainingPlan`/`TrainingDay` irgendwo in Phase 2.
* Keine KI-/Netzwerk-Abhängigkeit.
* Keine neue Deload-Engine — nur `DeloadAdvisor`-Ergebnis durchreichen.
* Keine erfundenen RPE-/HF-/Dauerwerte.
* PR #4 bleibt ungemergt während der gesamten Umsetzung.

---

## Phase 2A — Audit und Datenmodell

Audit bereits erledigt (Design-Dokument Abschnitt 0 + "Architekturprüfung
der offenen Punkte"). Diese Teilphase implementiert ausschließlich das
vereinheitlichte Aktivitätsmodell und die Wochen-/Tagesaggregation — noch
keine Bewertungslogik, noch keine UI, keine `UserBodyProfile`-Änderung.

**Status: IMPLEMENTIERT.** Die folgenden Signaturen sind die tatsächlich
umgesetzten (nicht mehr nur geplant) — ersetzen den ursprünglichen,
`Kind`-Enum-basierten Entwurf (siehe Design-Dokument Abschnitt 1 für die
Begründung der Korrektur).

### Neue Dateien

**`Sources/DeltiqCore/Analytics/TrainingActivity.swift`**
```swift
public struct TrainingActivity: Sendable, Equatable {
    public let date: Date
    public let runningDistanceKm: Double?
    public let runningDurationSeconds: Int?
    public let isRunning: Bool
    public let isCrossTrainingOnly: Bool
    public let hasAmbiguousCardio: Bool
    public let hasStrengthActivity: Bool
    public let strengthSetCount: Int
    public let strengthVolumeKg: Double
    public init(date:runningDistanceKm:runningDurationSeconds:isRunning:
                isCrossTrainingOnly:hasAmbiguousCardio:hasStrengthActivity:
                strengthSetCount:strengthVolumeKg:)
    // internal, nur fuer TrainingLoadAggregator:
    var asCardioLoggedSession: CardioVolumeOverTimeAggregator.LoggedSession { get }
}
```
Unabhängige Flags statt exklusivem `Kind`-Enum (Design-Dokument Abschnitt
1) — identisches Prinzip wie `CardioVolumeOverTimeAggregator.LoggedSession`,
dessen Feldnamen/Semantik für die Cardio-Seite 1:1 übernommen werden.

**`Sources/DeltiqCore/Analytics/TrainingLoadWeek.swift`**
```swift
public struct TrainingLoadWeek: Sendable, Equatable, Identifiable {
    public let weekStart: Date
    public let running: CardioVolumeOverTimePoint   // eingebettet, nicht kopiert
    public let strengthSessionCount: Int
    public let strengthSetCount: Int
    public let strengthVolumeKg: Double
    public var id: Date { weekStart }
}
```
`otherEnduranceSessionCount`/`ambiguousActivityCount`/
`hardStrengthSessionCount` aus dem ursprünglichen Entwurf entfallen:
erstere zwei sind bereits `running.crossTrainingSessionCount`/
`running.ambiguousCardioSessionCount` (redundant gewesen), letztere ist
2C-Scope (Intensitätsklassifikation).

**`Sources/DeltiqCore/Analytics/TrainingLoadAggregator.swift`**
```swift
public enum TrainingLoadAggregator {
    public static func aggregate(
        activities: [TrainingActivity],
        windowStart: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TrainingLoadWeek]
}
```
**Korrektur gegenüber dem ursprünglichen Entwurf:** kein separater
`runningSeries`-Parameter — `aggregate` ruft
`CardioVolumeOverTimeAggregator.aggregate` INTERN selbst auf (über
`activities.map(\.asCardioLoggedSession)`), damit der Aufrufer
(`TrainingActivityExtractor`-Konsument) nicht zwei Aggregationsschritte
selbst orchestrieren muss. Die Kraft-Zahlen werden separat, mit
identischem Gap-Filling-Prinzip, pro Woche aufsummiert und auf das
bereits lückenlose `CardioVolumeOverTimeAggregator`-Ergebnis gemappt
(kein zweites Lücken-Füllen).

**`Sources/DeltiqData/TrainingActivityExtractor.swift`**
```swift
public enum TrainingActivityExtractor {
    public static func extract(from sessions: [WorkoutSession]) -> [TrainingActivity]
}
```
Datenfluss (siehe Design-Dokument "Architekturprüfung Teil 2" für die
vollständige Herleitung): `sessions.filter(\.isRealWorkout)` gezippt mit
`CardioHistoryExtractor.loggedSessions(from: sessions)` (identischer
interner Filter, identische Reihenfolge — sicher per Index kombinierbar).
Kraft-Zahlen NICHT aus `session.totalSets`/`totalVolumeKg` (die zählen
Cardio-"Sätze" mit, siehe Design-Dokument), sondern frisch aus
`session.loggedSets.filter { !$0.resolvedIsCardio }` über
`SessionAggregator.totals` (Bestandsformel, unverändert).

### Tests 2A (Ticket-Testfälle 1–9, 12–14)

`Tests/DeltiqCoreTests/TrainingLoadAggregatorTests.swift` (reine Funktion,
lokal ausführbar und ausgeführt):
1. Reine Laufwoche → Kraft-Zahlen exakt 0.
2. Reine Krafttrainingswoche → Lauf-Zahlen exakt 0.
3. Kombinierte Woche → beide Zahlen unabhängig korrekt, nie vermischt.
4. Radfahren → nie in `runningDistanceKm`.
5. Unbekannte Sportart → nie `.running` oder Kraft.
10/11. Unvollständige Historie / fehlende Distanz bleibt `nil`→0-Beitrag,
   nie erfunden; Lücken-Wochen bleiben im Fenster vollständig gefüllt.
14. Determinismus: gleiche Eingabe, zwei Aufrufe, identisches Ergebnis.
Zusätzlich: Bodyweight-Grenzfall (0 kg Volumen, aber `strengthSessionCount
== 1`, nicht 0 — unterscheidbar von "keine Kraftarbeit").

`Tests/DeltiqDataTests/TrainingActivityExtractorTests.swift`:
6. Bodyweight-Sätze zählen (`strengthSetCount`), 0 kg Volumen, kein
   erfundenes Gewicht.
7. Kettlebell-Sätze wie jeder andere Gewichts-Satz.
8. Mehrere Übungen in einer Session → EINE `TrainingActivity`, Summen
   korrekt.
9. Mehrere Sessions in einer Woche → separate `TrainingActivity`-Einträge.
12. Gelöschte Exercise mit Snapshot → `strengthSetCount`/`strengthVolumeKg`
    bleiben über `resolvedIsCardio` snapshot-first korrekt.
13. Keine Doppelzählung: Extractor-Ergebnis vs. unabhängig gepflegtes
    `session.totalVolumeKg` (`recomputeTotals()`) — nicht addiert.
    Zusätzlich: Platzhalter-Zeilen (DEL-223) zählen nicht mit;
    Run+Strength-"Brick" in einer Session hält beide Zahlen unabhängig
    sichtbar; unvollständige/Ruhetag-Sessions ausgeschlossen.

**Regressionstest Phase 1 (Testfall 15):** keine neue Datei nötig — 2A
ändert keine bestehende Phase-1-Datei (`CardioHistoryExtractor`,
`CardioVolumeOverTimeAggregator`, `RaceProgressAssessment`,
`RaceProgressCardModel`, `HeartRateZoneCalculator` alle unverändert), der
bestehende grüne Phase-1-Testlauf in CI ist der Regressionsnachweis.

---

## Phase 2B — Belastungsanalyse

**Status: IMPLEMENTIERT.** Abweichungen vom urspruenglichen Entwurf (anderer
Dateiname, deutlich reichhaltigerer Typ als die skizzierte `Trend`-Struct,
kein `HeartRateZoneCalculator`-Bezug — der gehoert zu 2D, nicht 2B) sind
unten dokumentiert.

### Neue Datei

**`Sources/DeltiqCore/Analytics/TrainingLoadTrendAnalyzer.swift`** — einziger
Eintrittspunkt `analyze(weeks:now:calendar:) -> TrainingLoadTrend`, reine
Funktion auf `[TrainingLoadWeek]` (2A-Output, unveraendert konsumiert, keine
zweite Wochenaggregation).

**Zentrale, dokumentierte Konstanten:**
```swift
comparisonWindowWeeks = 5                 // Fenster fuer Variationskoeffizient
moderateIncreaseThreshold = 0.25          // identisch zu RaceProgressAssessment.loadIncreaseThreshold
significantIncreaseThreshold = 0.50       // Ticket-Beispiel 18km->27km
variabilityCoefficientThreshold = 0.30    // neu, da "stark schwankend" in Phase 1 kein Vorbild hat
minimumCompleteWeeksForTrend = 3
acuteChronicChronicWindowWeeks = 4        // 4 Wochen = 28 Tage bei Wochengranularitaet
```

**Kernlogik — pro Kennzahl (`WeeklyMetricTrend`), zwei GETRENNTE Vergleiche:**
1. `changeVsPreviousCompleteWeek`: strikter Paarvergleich letzte
   vollstaendige Woche gegen GENAU die eine Woche davor.
2. `changeVsPreviousWeeksAverage`: aktuelle (ggf. unvollstaendige) Woche
   gegen den Durchschnitt ALLER historischen vollstaendigen Wochen — treibt
   `classification` (Ticket-Beispiel-Berechnung: 18/18/18km Basis, 27km
   aktuell = exakt +50%). **Wichtige Invariante, waehrend der Testerstellung
   als Bug gefunden und korrigiert:** die historische Vergleichsbasis wird
   STRUKTURELL aus `weeks.dropLast()` gebildet, nie aus einer reinen
   Vollstaendigkeits-Filterung des GESAMTEN Arrays — sonst koennte eine
   bereits kalendarisch vollstaendige "aktuelle" Woche in ihre EIGENE
   Vergleichsbasis einfliessen und den Vergleich verfaelschen.
3. `changeOver28Days`: Durchschnitt der letzten 4 vs. der 4 Wochen davor
   (Ticket: "28-Tage-Entwicklung"), `nil` ohne 8 vollstaendige Wochen.

`classify(...)` prueft in dieser Reihenfolge: (a) Datenbasis
(`historicalWeekCount >= 3`, sonst `.insufficientData`), (b)
Variationskoeffizient ueber das Vergleichsfenster (`>= 0.30` →
`.highlyVariable`, VOR jeder gerichteten Trendaussage — ein schwankender
Verlauf mit zufaellig hohem letzten Wert ist kein verlaesslicher
"Anstieg"), (c) Prozentveraenderung gegen die drei Schwellen. Beide
Vergleichswerte `0` (eine Disziplin, die nicht stattfindet) → `.notApplicable`,
nie Datenmangel oder Warnung.

**`combineLoadDevelopment`:** kombiniert NUR Lauf-Distanz und Kraft-Volumen
(die beiden Kennzahlen mit echter Groessenordnung — nie Ausdauer-Distanz
und Kraft-Volumen, Ticket Teil 4). Beide Disziplinen werden UNABHAENGIG
klassifiziert, das schwerwiegendere Ergebnis gewinnt, beide werden als
ausloesende `Discipline`(n) genannt — niemals "allein anhand der
Laufkilometer" bewertet, wenn Krafttraining gleichzeitig eskaliert.

**Acute:Chronic (`acuteChronicRatio`):** ausschliesslich Lauf-Distanz, `nil`
ohne 4 vollstaendige Wochen VOLLSTAENDIG innerhalb der bekannten Historie
(`weeks` ist bereits exakt darauf begrenzt) und `nil` bei chronischem
Durchschnitt `0` (Divisionsschutz UND ein Sprung von 0 auf irgendeinen Wert
ist kein sinnvolles Verhaeltnis). Rein interne Kennzahl, nie die zentrale
Coach-Aussage.

**`TrainingLoadDataCompleteness`** (`complete`/`partial`/`insufficient` +
`Reason`-Liste): `.durationDataUnavailable` ist IMMER gesetzt (siehe unten),
daher kann das Ergebnis aktuell nie `.complete` sein — ehrlich, nicht
erfunden. Weitere Gruende: `shortHistory`, `currentWeekIncomplete`,
`missingRunningDistance` (Sessions gezaehlt, aber 0 km — mit hoher
Wahrscheinlichkeit unbekannte Distanz, siehe Modellgrenze unten),
`unknownActivityPresent`.

**Dokumentierte Modellgrenze (Ticket: "dokumentiere das Problem, erfinde
keine Ersatzwerte"):** `CardioVolumeOverTimePoint` (Phase 1, von
`TrainingLoadWeek.running` eingebettet) traegt keine Lauf-Gesamtdauer (nur
Durchschnitts-Pace) und `TrainingActivity`/`TrainingLoadWeek` (2A) tragen
keine Distanz/Dauer fuer sonstige Ausdaueraktivitaeten (nur eine
Sessionzahl) und keine Gesamttrainingsdauer irgendeiner Disziplin
(`WorkoutSession.durationMinutes` existiert auf SwiftData-Ebene, wurde von
2A's `TrainingActivityExtractor` aber nicht abgegriffen). Eine Erweiterung
dieser bereits abgeschlossenen Arbeitspakete war ausserhalb des
2B-Auftrags — `OverallTrainingSummary.weeklyTotalDurationSeconds` bleibt
daher bewusst ein `Int?`-Feld, das heute immer `nil` ist (identisches
Prinzip wie `CardioVolumeOverTimePoint.averageHeartRateBpm` in Phase 1 —
die Spalte existiert, damit eine spaetere Phase sie nicht neu einfuehren
muss, aber niemand errät ihren Wert). Gleiches gilt fuer "Gesamtanzahl
Trainingseinheiten": eine Session kann gleichzeitig Lauf- UND Krafttraining
enthalten ("Brick"), `TrainingLoadWeek` haelt das nicht separiert fest -
eine ungeprüfte Summe ueber alle Disziplinen koennte doppelt zaehlen, daher
bewusst NICHT modelliert statt einer scheinbar exakten, aber potenziell
falschen Zahl.

### Tests

`Tests/DeltiqCoreTests/TrainingLoadTrendAnalyzerTests.swift` — 26 Tests,
lokal kompiliert UND ausgefuehrt (reine Funktion, kein SwiftData):
deckt alle 24 Ticket-Testfaelle (stabiles/steigendes/sinkendes/schwankendes
Laufvolumen, steigendes Kraftvolumen, sinkende Kraftfrequenz unabhaengig
vom Volumen, kombinierte Wochen, Radfahren ohne Laufkilometer, mehrere
Sportarten in einer Woche, fehlende Distanz/Dauer, historische Luecke,
keine/eine Vergleichswoche, 0-Basis-Woche, unvollstaendige aktuelle Woche,
Zeitzonen-/Wochen-/Jahres-/Schaltjahr-Grenzen, unbekannte Aktivitaet, ACR
bei <28/genau 28/Fenster-vor-Historie-Tagen, Determinismus) plus Grenzfaelle
(leeres Array, Null-Mittelwert ohne NaN, ACR bei chronischem
Durchschnitt 0, negativer Eingabewert).

**Regressionstest Phase 1 (Testfall 24):** keine neue Datei noetig — 2B
aendert keine bestehende Phase-1- oder 2A-Datei, der bestehende gruene
Testlauf in CI ist der Regressionsnachweis.

---

## Phase 2C — Regeneration

### Neue Dateien

**`Sources/DeltiqCore/Analytics/SessionDensityFlag.swift`** (Enum, siehe
Design-Dokument Abschnitt 5).

**`Sources/DeltiqCore/Analytics/TrainingLoadAssessment.swift`** — die
zentrale, deterministische Bewertung (Design-Dokument Abschnitt 8,
vollständige Typdefinition dort). Enthält:
```swift
public static func assess(_ input: Input) -> Assessment
private static func classifyDays(_ activities: [TrainingActivity]) -> [Date: SessionDensityFlag]
private static func recoverySpacingConcern(_ flags: [Date: SessionDensityFlag]) -> Concern?
private static func crossDisciplineConcern(_ week: TrainingLoadWeek, _ flags: ...) -> Concern?
```
Konstanten (zentral, dokumentiert, Ticket-Vorgabe 5.2/"zentral definieren
und testen"):
```swift
public static let minimumBackToBackHardDaysForConcern = 2
public static let backToBackWindowDays = 14
```

**`Sources/DeltiqData/TrainingLoadDueCalculator.swift`** — Vorbild
`RaceProgressDueCalculator` 1:1 (State-Enum `due`/`notYetDue`/`unknown`,
`establishObservationAnchorIfNeeded`, `recordAnalysisCompleted`). Neue
`UserBodyProfile`-Felder (additiv, Default `nil`, keine Migration nötig):
`trainingLoadLastAnalyzedAt: Date?`,
`trainingLoadLastAnalyzedConfigurationFingerprint: String?`,
`trainingLoadDismissedFingerprint: String?`.

### Tests 2C (Testfälle 22–32)

`Tests/DeltiqCoreTests/TrainingLoadAssessmentTests.swift`:
22. Dicht aufeinanderfolgende anspruchsvolle Einheiten erkannt, NUR wenn
    `sessionFeelingRaw` vorliegt oder Teil eines Lastanstiegs — niemals
    automatisch aus bloßer Häufigkeit.
23. Erholungsabstände korrekt berechnet (Tage zwischen zwei als hart
    markierten Tagen).
24. Kraft- UND Lauftraining gemeinsam berücksichtigt
    (`trainingDensityAcrossDisciplines`-Concern nur bei beiden
    Disziplinen in derselben Woche).
25. Fehlende Daten nicht als Erholung interpretiert — eine Lücken-Woche
    erzeugt `DataGap.geniuneGapWeeks`, NIE automatisch `.balanced`.
26. Keine medizinische Risikodiagnose — reiner String-/Vokabular-Audit
    (kein `Concern`/`Outcome`-Case erwähnt Verletzung/Diagnose/Risiko als
    Tatsachenbehauptung; Structural-Guard-Test auf die lokalisierten
    Strings, Vorbild `RaceProgressPhase1StructuralGuardTests`).
27. Deload-Empfehlungen mit nachvollziehbaren Gründen — `restWeekSuggested
    (reasons:)` liefert IMMER mindestens einen `RestWeekReason`, nie ein
    leeres Array.
28. Gleiche Eingaben → gleiche Bewertung (reiner Determinismus-Test: zwei
    identische `Input`-Werte, `assess` zweimal aufgerufen, `Assessment ==`).
29. Empfehlungen enthalten konkrete Datengrundlagen (jeder `Concern`-Case
    trägt seine Zahlen als Payload — Test prüft, dass KEIN Case ohne
    Zahlenfeld existiert außer den reinen Durchreich-Fällen
    `deloadRecommended`/`comebackSuggested`, die ihrerseits bereits
    begründete Payloads tragen).
30. Unzureichende Daten → `insufficientData` bzw. passende `DataGap` (Analog
    Testfall 6 aus Phase 1/RaceProgressAssessment).
31. Profiländerungen aktualisieren die Bewertung — `TrainingLoadCardModel.
    make` liest Eingaben frisch bei jedem Aufruf (kein Caching, Vorbild
    `RaceProgressCardModel.make`-Test aus dem Dashboard-Fix-Ticket:
    `testChangingProfileMaxHeartRateBetweenTwoMakeCallsProducesFreshly...`
    — äquivalenter Test hier für `maxHeartRateBpm`-Änderung und für neue
    Sessions).
32. Zielwechsel (`cardioGoal`/`cardioRaceDate`) beeinflusst Phase 2 NICHT —
    `TrainingLoadAssessment.Input` enthält überhaupt kein Ziel-/Renndatum-
    Feld; Regressionstest: `RaceProgressCardModel`-Fingerprint-Änderung
    löst keine Änderung an `TrainingLoadCardModel`-Ergebnis aus
    (Unabhängigkeits-Test über zwei getrennte `.make`-Aufrufe).

`Tests/DeltiqDataTests/TrainingLoadDueCalculatorTests.swift`: Vorbild
`RaceProgressDueCalculatorTests`/`RaceProgressPersistenceTests` 1:1
(inkl. echter Store-Restart-Test für die drei neuen Profilfelder).

---

## Phase 2D — Coaching und UI

### Neue Dateien

**`Sources/DeltiqCore/Programs/DashboardWidgetType.swift`** (Erweiterung,
nicht neu): `case trainingLoadCard` ans Ende angehängt, `defaultOrder`
erweitert (Design-Dokument Abschnitt 0.6/9 — KEIN Top-Schieben-Verhalten,
anders als `.raceProgressCard`).

**`Sources/DeltiqUI/Cardio/TrainingLoadCardModel.swift`** — Vorbild
`RaceProgressCardModel` 1:1:
```swift
public struct TrainingLoadCardModel: Equatable {
    public let weeks: [TrainingLoadWeek]
    public let assessment: TrainingLoadAssessment.Assessment
    public let dueState: TrainingLoadDueCalculator.State
    public let heartRateZoneContext: HeartRateZoneDisplayState  // durchgereicht
    public let configurationFingerprint: String
    public let dismissalFingerprint: String

    public static func make(allSessions: [WorkoutSession], profile: UserBodyProfile, now: Date = Date()) -> TrainingLoadCardModel?
    public func dismiss(profile: UserBodyProfile)
    @MainActor public func recordAnalysisShown(for profile: UserBodyProfile, in context: ModelContext, now: Date = Date())
}
```
`make` liefert NIE `nil` aus Aktivierungsgründen (anders als
`RaceProgressCardModel` — kein Coaching-Flag gated Phase 2, Design-
Dokument 0.6); `nil` nur bei technischem Fehler (keiner vorgesehen —
Rückgabetyp bleibt trotzdem optional für Konsistenz mit dem etablierten
Muster und für zukünftige Erweiterbarkeit, OHNE dass aktuell ein
Pfad `nil` zurückgibt).

**`Sources/DeltiqUI/Cardio/TrainingLoadDetailView.swift`** — Vorbild
`RaceProgressDetailView`, 9 Sections exakt nach Ticket Teil I:
Wochenübersicht, Laufbelastungs-Trend, Krafttrainingsübersicht, andere
Ausdaueraktivitäten, Trainingsverteilung, Erholungsabstände, Auffälligkeiten,
Empfehlungen, Datenvollständigkeit.

**`Sources/DeltiqUI/DashboardView.swift`** — neuer `case
.trainingLoadCard: trainingLoadDashboardCard` im bestehenden Switch (Vorbild
exakt der `.raceProgressCard`-Eintrag aus dem Dashboard-Fix), neue
`@State private var showingTrainingLoadDetail = false` + `.sheet`.

**Lokalisierung** — neues `.scripts/training_load_phase2_keys.py`
(Vorbild `heart_rate_zone_keys.py`, `PYTHONUTF8=1` beim Ausführen
beachten — siehe Lektion aus dem Dashboard-Fix-Ticket), DE/EN/TR für:
Widget-Name, 5 `Outcome`-Überschriften, alle `Concern`-/`DataGap`-Texte,
die 9 Detail-Section-Header, das Ticket-Beispiel aus Teil F als Vorlage
für `trainingDensityAcrossDisciplines`-Text.

### Tests 2D (Testfälle 33–43)

`Tests/DeltiqCoreTests/DashboardWidgetTypeTrainingLoadCardTests.swift`
(Vorbild `DashboardWidgetTypeRaceProgressCardTests`):
33. Karte unabhängig konfigurierbar (eigener Case, kein Koppeln an
    `.raceProgressCard`/`.runCoachCard`).

`Tests/DeltiqDataTests/DashboardWidgetPersistenceTests.swift`
(Erweiterung der bestehenden Datei, nicht neu):
34. Widget-Einstellungen nach echtem Store-Neustart erhalten
    (`.trainingLoadCard` im Custom-Order-Test ergänzt).
35. Deaktivierte Karte erscheint nicht (`activeDashboardWidgets`-Filter-
    Test).
36. Reihenfolge bleibt nach Neustart erhalten (bereits vom bestehenden
    Persistenz-Test-Muster abgedeckt, nur mit der neuen Karte in der
    Order-Liste).
37. Bestehende Karten bleiben funktionsfähig —
    Regressionstest: `.raceProgressCard`/`.runCoachCard`-Tests aus den
    vorherigen Tickets laufen unverändert weiter (kein neuer Test, reine
    CI-Bestätigung).

`Tests/.../Phase1RegressionGuardTests.swift` (neue, schlanke Datei, NUR
Aufruf bestehender Assertions mit frischen Daten, kein neuer
Produktionscode):
38. Historische Laufkilometer bleiben korrekt (ruft bestehenden
    `CardioVolumeOverTimeAggregator`-Pfad mit denselben Fixtures wie
    Phase 1 auf, zusätzlich durch `TrainingActivityExtractor` geleitet —
    Ergebnis muss identisch sein).
39. HealthKit-Backfill bleibt idempotent (bestehender
    `ExternalWorkoutImportServiceSportKindTests`-Test läuft unverändert —
    CI-Bestätigung, kein neuer Code).
40. Sportart-Snapshots bleiben erhalten (bestehender
    `ExerciseLogEnduranceSportKindTests` — CI-Bestätigung).
41. Race-Progress-Bewertung bleibt korrekt (bestehende
    `RaceProgressAssessmentTests`/`RaceProgressCardModelTests` — CI-
    Bestätigung, PLUS der neue Unabhängigkeits-Test aus Testfall 32).
42. Herzfrequenzzonen bleiben korrekt (bestehende
    `HeartRateZoneCalculatorTests`/`HeartRateZoneContextBuilderTests` —
    CI-Bestätigung).
43. Bestehende Wettkampfziel-/Plananpassungslogik unangetastet —
    Structural-Guard-Test: keine der neuen Phase-2-Dateien importiert/
    ruft `CoachAdjustmentCardModel`/`PlanGeneratorInstantiator`/
    `applyCoachCardioAdjustment` (Vorbild
    `testPhase1NeverImportsPlanMutationAPIs`, erweitert um die neuen
    Dateien in der Scanliste).

---

## Reihenfolge der Commits (Vorschlag, an Phase-1-Konvention angelehnt)

1. `feat(load): add unified TrainingActivity model and extractor` (2A)
2. `feat(load): add TrainingLoadWeek aggregation` (2A)
3. `feat(load): add trend calculation for running and strength` (2B)
4. `feat(load): add TrainingLoadAssessment with density/recovery concerns` (2C)
5. `feat(load): add TrainingLoadDueCalculator + UserBodyProfile fields` (2C)
6. `feat(load): add trainingLoadCard dashboard widget + detail view` (2D)
7. Lokalisierung als eigener kleiner Commit (2D)

Nach jedem Commit: `swift build --target DeltiqCore` lokal (Windows-
Verifikation, wie in den vorherigen Tickets etabliert), volle macOS-CI erst
am Ende von 2D, dann vollständiger Abschlussbericht mit Commit-SHA,
Testergebnissen und offenen Einschränkungen — wie vom Ticket in Schritt 6–8
der Vorgehensweise verlangt.
