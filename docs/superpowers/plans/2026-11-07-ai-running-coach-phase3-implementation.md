# AI Running Coach – Phase 3: Implementierungsplan

Datum: 2026-11-07  
Spec: `docs/superpowers/specs/2026-11-07-ai-running-coach-phase3-design.md`  
Branch: `claude/great-dewdney-af8974`  
Status: **WARTEND AUF FREIGABE**

---

## Global Constraints

- Kein neues SwiftData-Feld außer `profile.activeDashboardWidgets` (wird bereits in WP-D geschrieben).
- Keine automatische Trainingsplanänderung.
- Keine medizinischen Formulierungen.
- PR #4 bleibt ungemergt.
- `swift test` auf Windows durch ZIPFoundation blockiert — Verifikation auf macOS CI.
- Nach jedem Work Package `swift build --target DeltiqCore` lokal ausführen (Typ-Prüfung).
- `cardioJunkMiles` bleibt intentional inaktiv (kein Bug, bewusste Entscheidung).
- `chartPoints`, `chartPhases`, `ChartPhase` bleiben tot — kein Aufräumen in Phase 3.

---

## Architektur-Entscheidungen (geklärt 2026-11-07)

Alle offenen Fragen sind entschieden — keine Blockaden vor WP-A:

| Entscheidung | Ergebnis |
|---|---|
| A: Platzierung `IntegratedCoachingOutcome` | `CardioCoachDetailView` (neue Section, neue Parameter) — Details in Spec §9 |
| B: `cardioJunkMiles` aktivieren | NEIN — bleibt deaktiviert; Phase 4. Drei harte Blocker: kein per-Tag-Zieltempo, kein Profil-Tempo, kein Dauerdaten — Details in Spec §9 |
| C: Widget-Repositionierung | Bei jeder Aktivierung AUS→EIN, top-3-Guard, in `CardioGoalEditorView.save()` — Details in WP-D |
| D: Volumen-Schwellenwerte | 15 % bei weeksToRace < 10; 10 % sonst — Details in Spec §9 |

**Zwei Prioritäts-Korrekturen** (Architektur-Review):
- Prio 3 `isCrossTrainingOnly` → `.buildRunningBase` (war `.maintainCurrent` — fachlich falsch für Läufer:innen mit Renndatum)
- Prio 6 `recentTrainingGap` → `.buildRunningBase` (war `.reduceLoadThisWeek` — nach Pause ist Volumen bereits niedrig; weiter reduzieren ist kontraproduktiv)

---

## Abhängigkeitsgraph

```
WP-A (IntegratedRunCoachAdvisor) ──► WP-B (CardioCoachDetailView Section)
                                              │
WP-C (RaceProgressDetailView)      ──────────┤ (unabhängig)
WP-D (ProfileEditorView onChange)  ──────────┤ (unabhängig)
                                              │
WP-E (Localization) ◄────────────────────── alle WPs
```

WP-C und WP-D sind vollständig unabhängig voneinander und von WP-A. WP-E sammelt alle neuen Keys.

---

## Work Package A — `IntegratedRunCoachAdvisor` in DeltiqCore

### Ziel
Neue pure function, die Outputs aus allen drei parallelen Pipelines (Race Progress, Training Load/Density, Feasibility) zu einer einzigen priorisierten Coaching-Aussage zusammenführt. Kein SwiftData, kein @MainActor.

### Betroffene Dateien
- `Sources/DeltiqCore/Analytics/IntegratedRunCoachAdvisor.swift` **(NEU)**
- `Sources/DeltiqCore/Analytics/IntegratedCoachingOutcome.swift` **(NEU)**

### Neue Typen (Pseudo-Swift)

```swift
// IntegratedCoachingOutcome.swift
// ⚠️ Maßgeblich: Spec §3.4 — diese Typen exakt so implementieren
public enum CoachingAction: Sendable, Equatable {
    case maintainCurrent
    case reduceLoadThisWeek
    case increaseWeeklyVolume(targetPercent: Double)
    case reassessGoal
    case planAdjustmentAvailable
    case buildRunningBase
    case insufficientData  // KEIN associated value
}

public enum DataQualityIssue: Sendable, Equatable {
    case runningDistanceMissing(weekCount: Int)
    case ambiguousActivitiesPresent(weekCount: Int)
    case durationDataUnavailable
    case historyTooShort(weeksAvailable: Int, weeksNeeded: Int)
}

public enum CoachingRationale: Sendable, Equatable {
    case positiveProgressHighLoad
    case positiveProgressStableLoad
    case plateauNearRace(weeksToRace: Int)
    case goalLikelyUnreachable
    case recentGapDetected
    case recoveryNeeded
    case noRunningData
    case crossTrainingOnly
    case shortHistory
    case planJustAdjusted
}

public struct IntegratedCoachingOutcome: Sendable, Equatable {
    public let primaryAction: CoachingAction  // war fälschlich "action"
    public let rationale: CoachingRationale
    public let dataQualityIssues: [DataQualityIssue]  // war fälschlich in CoachingRationale + "confidence"
}
```

```swift
// IntegratedRunCoachAdvisor.swift
public enum IntegratedRunCoachAdvisor {
    public static func assess(
        raceProgress: RaceProgressAssessment.Assessment?,
        loadTrend: TrainingLoadTrend?,
        densityAssessment: TrainingDensityAssessment?,
        goal: CardioGoal?,
        weeksToRace: Int?,
        planAdjustmentPending: Bool
    ) -> IntegratedCoachingOutcome
}
```

### Prioritätsreihenfolge (12 Stufen, oben = höchste Priorität)

| Priorität | Bedingung | Action |
|-----------|-----------|--------|
| 1 | `loadTrend == nil` ODER `dataCompleteness == .insufficient` | `.insufficientData` |
| 2 | Keine Lauf-Sessions (runningSessionCount == 0 letzte 4 Wochen) | `.buildRunningBase` |
| 3 | Nur Cross-Training (`isCrossTrainingOnly` dominant) | `.buildRunningBase` ← **korrigiert** |
| 4 | `planAdjustmentPending == true` | `.planAdjustmentAvailable` |
| 5 | `concerns.contains(.goalLikelyUnrealistic)` | `.reassessGoal` |
| 6 | `concerns.contains(.recentTrainingGap)` | `.buildRunningBase` ← **korrigiert** |
| 7 | `concerns.contains(.insufficientRecovery)` | `.reduceLoadThisWeek` |
| 8 | `concerns.contains(.loadIncreasedTooFast)` ODER `loadDevelopment == .significantIncrease` | `.reduceLoadThisWeek` |
| 9 | `concerns.contains(.volumePlateau) && weeksToRace != nil && weeksToRace! < 10` | `.increaseWeeklyVolume(targetPercent: 0.15)` |
| 10 | `concerns.contains(.volumePlateau) && (weeksToRace == nil \|\| weeksToRace! >= 10)` | `.increaseWeeklyVolume(targetPercent: 0.10)` |
| 11 | `outcome == .onTrack` + `loadDevelopment == .stable/.declining` | `.maintainCurrent` |
| 12 | Alles andere | `.maintainCurrent` |

### Präzisierungen für Prioritätsregeln 1, 2, 3 und 6

**Prio 1 — Drei unterschiedliche Datenzustände (nicht vermischen!):**
Die Prio-1-Trigger `loadTrend == nil` und `dataCompleteness == .insufficient` decken zwei verschiedene Szenarien ab:
- `loadTrend == nil`: Kein einziges Training vorhanden (`activities.isEmpty` → `cachedLoadTrend` bleibt `nil`)
- `dataCompleteness == .insufficient`: Sessions vorhanden, aber `historicalWeekCount < 3` (`minimumCompleteWeeksForTrend`, `TrainingLoadTrendAnalyzer.swift:41`)
- `dataCompleteness == .partial`: ≥ 3 Vergleichswochen vorhanden, aber Datenlücken (z.B. fehlende Distanz, keine Dauer). **KEIN Prio-1-Trigger** — Prios 2–12 laufen durch.

`dataCompleteness == .complete` wird NIEMALS zurückgegeben, da `.durationDataUnavailable` immer als `Reason` angehängt wird (das Datenmodell erfasst keine Laufdauer, `TrainingLoadTrendAnalyzer.swift:319`). Fehlende optionale Belastungsdaten dürfen eine ansonsten mögliche Rennverlaufs-Bewertung nicht blockieren.

Testfälle Prio 1:
- `testInsufficientData_noSessions` — `loadTrend == nil` → `.insufficientData` / `.shortHistory`
- `testInsufficientData_shortHistory` — `dataCompleteness == .insufficient` (< 3 Wochen) → `.insufficientData`
- `testPartialData_prios2to12EvaluateNormally` — `dataCompleteness == .partial`, `raceProgress != nil` → Prio 2–12 werden ausgewertet (kein Prio-1-Kurzschluss)

**Prio 2 — Ableitung von `runningSessionCount` aus `weeklyFlags`:**
Prio 2 feuert, wenn keine der letzten 4 ausgewerteten Wochen (exkl. `.beforeCoachingObservationPeriod`) Laufaktivität enthält:
```swift
let evaluated = raceProgress.weeklyFlags
    .filter { $0 != .beforeCoachingObservationPeriod }
    .suffix(4)
// Prio 2: evaluated.allSatisfy { $0 != nil }
// (nil = Woche mit Lauf; .crossTrainingOnlyWeek / .strengthOnlyWeek / .genuineGap / .ambiguousActivityWeek = kein Lauf)
```

**Prio 3 — Schwellenwert für "dominant" und Klassifikation gemischter Sessions:**
"isCrossTrainingOnly dominant" = mindestens 3 der letzten 4 ausgewerteten Wochen sind `.crossTrainingOnlyWeek`:
```swift
let evaluated = raceProgress.weeklyFlags
    .filter { $0 != .beforeCoachingObservationPeriod }
    .suffix(4)
let crossTrainingCount = evaluated.filter { $0 == .crossTrainingOnlyWeek }.count
// Prio 3: crossTrainingCount >= 3
```

⚠️ **Namens-Falle — `isCrossTrainingOnly` auf `LoggedSession` ist IRREFÜHREND:**
`CardioHistoryExtractor.swift:51`: `isCrossTrainingOnly = !cyclingLogs.isEmpty` — fires für JEDE Session mit Cycling, unabhängig davon, ob auch Running vorhanden ist. Eine gemischte Lauf+Rad-Session hat also `isRunning = true` UND `isCrossTrainingOnly = true` gleichzeitig.

Folge im Aggregator (`CardioVolumeOverTimeAggregator.swift:88`): Beide Zähler werden inkrementiert:
```swift
if session.isRunning { bucket.runningSessionCount += 1 }
if session.isCrossTrainingOnly { bucket.crossTrainingSessionCount += 1 }
```

Die `WeeklyFlag`-Klassifikation (`RaceProgressAssessment.swift:191`) prüft ZUERST `runningSessionCount > 0`:
```swift
if point.runningSessionCount > 0 { return nil }  // → Laufwoche (nil) — KORREKT
if point.crossTrainingSessionCount > 0 { return .crossTrainingOnlyWeek }
```

**Eine gemischte Lauf+Rad-Woche wird korrekt als Laufwoche (`nil`) klassifiziert, NICHT als `.crossTrainingOnlyWeek`.** Prio 3 kann nur feuern, wenn `runningSessionCount == 0` in dieser Woche. Die Namens-Verwirrung auf Session-Ebene führt NICHT zu Fehlklassifikationen auf Wochenebene.

Testfälle Prio 3 (am `IntegratedRunCoachAdvisor`):
- `testCrossTraining_pureCyclingWeek` — 1 Woche nur Radfahren → `.crossTrainingOnlyWeek` → kein Prio-3-Feuer (< 3 von 4)
- `testCrossTraining_mixedRunCyclingWeek` — Lauf+Rad in einer Session → `nil` (Laufwoche) → `.crossTrainingOnlyWeek` NICHT gesetzt
- `testCrossTraining_pureRunning` — nur Laufen → `nil` (Laufwoche) ✓
- `testCrossTraining_unknownActivity` — unbekannte Cardio, kein Lauf → `.ambiguousActivityWeek` ✓
- `testCrossTraining_threeCrossOneRun` — 3 × `.crossTrainingOnlyWeek`, 1 × `nil` (in beliebiger Reihenfolge innerhalb der letzten 4) → Prio 3 feuert
- `testCrossTraining_fourCrossTraining` — 4 × `.crossTrainingOnlyWeek` → Prio 2 feuert vorher (kein Lauf in 4 Wochen), Prio 3 unreachable

**Prio 6 — `recentTrainingGap`: Schwellenwert, unvollständige Wochen und Datenlücken:**
Prio 6 basiert auf `RaceProgressAssessment.minimumConsecutiveGapWeeksForConcern = 2` (Quellcode, `RaceProgressAssessment.swift:136`). **Eine einzige trainingsfreie Woche löst Prio 6 NICHT aus.** Erst zwei aufeinanderfolgende `.genuineGap`-Wochen (`trailingGenuineGapStreak >= 2`) triggern `recentTrainingGap`.

`.genuineGap` entsteht nur, wenn ALLE Zähler null sind:
```swift
// RaceProgressAssessment.swift:198
// (runningSessionCount == 0 && crossTrainingSessionCount == 0 
//  && strengthSessionCount == 0 && ambiguousCardioSessionCount == 0)
return .genuineGap
```
Eine Deload-Woche mit einem einzigen Workout (Kraft oder Rad) → `.strengthOnlyWeek` oder `.crossTrainingOnlyWeek`, KEIN `.genuineGap`.

⚠️ **Unvollständige laufende Woche kann als `.genuineGap` zählen:**
`CardioVolumeOverTimeAggregator` erstellt einen Bucket für JEDE Woche im Fenster, auch die aktuelle unvollständige. Wenn der Nutzer noch nichts in der laufenden Woche geloggt hat, erscheinen alle Zähler als 0 → `.genuineGap`. Damit: 1 abgeschlossene Gap-Woche + laufende Woche ohne Session = streak 2 → Prio 6 feuert. Dies ist BEABSICHTIGT (Daten spiegeln Realität wider) und selbstkorrigierend: sobald eine Session geloggt wird, verschwindet der `.genuineGap` der aktuellen Woche.

⚠️ **Geplante Trainingspause nicht unterscheidbar von ungeplanter Lücke:**
Das System kennt keine "geplante Ruhezeit"-Information aus dem Trainingsplan. Eine 2-wöchige Holiday-Pause mit null Workouts ist für das System identisch mit einer ungewollten Trainingspause. Dokumentierte Datenlücke — keine Falschaussage, keine Workaround-Implementierung.

⚠️ **Renndatum-Nähe:** Die Prio-6-Regel ignoriert `weeksToRace`. Wenn der Nutzer 1 Woche vor dem Rennen ein 2-wöchiges Taper hatte (reduzierte Belastung, aber irgendetwas geloggt → kein `.genuineGap`), feuert Prio 6 nicht. Falls das Taper lückenlos mit Workouts war: korrekt. Falls komplett pausiert: `.buildRunningBase` 1 Woche vor Rennen ist inhaltlich fragwürdig, aber durch `minimumConsecutiveGapWeeksForConcern = 2` nur bei 2+ komplett leeren Wochen erreichbar — ein echter Edge-Case.

Testfälle Prio 6:
- `testGap_oneCompleteGapWeek` — 1 genuineGap-Woche → streak = 1 < 2 → kein Prio-6-Feuer
- `testGap_twoCompleteGapWeeks` — 2 genuineGap-Wochen trailing → streak = 2 → Prio 6 feuert → `.buildRunningBase`
- `testGap_currentWeekNotYetLogged` — letzte abgeschlossene Woche = genuineGap, aktuelle Woche = noch kein Training → streak = 2 → Prio 6 feuert (self-correcting sobald Session geloggt)
- `testGap_deloadWeekWithOneWorkout` — Woche mit nur Krafttraining → `.strengthOnlyWeek`, KEIN genuineGap → streak reset
- `testGap_activePlan_noContext` — kein Plan-Information verfügbar → System kann geplante Pause nicht erkennen (Datenlücke dokumentiert)
- `testGap_preRaceRest` — 2 Wochen komplett leer vor Rennen → Prio 6 feuert (Edge-Case, inhaltlich grenzwertig)

### Tests
**Datei**: `Tests/DeltiqCoreTests/IntegratedRunCoachAdvisorTests.swift` (NEU)

Pflicht-Testfälle:
- `testInsufficientDataWhenBothNil` — nil input → `.insufficientData`
- `testPlanAdjustmentPriorityOverConcerns` — planAdjustmentPending=true + concerns vorhanden → `.planAdjustmentAvailable`
- `testGoalUnrealisticBeforeGap` — goalLikelyUnrealistic + recentTrainingGap gleichzeitig → `.reassessGoal`
- `testLoadReductionFromACR` — nur ACR > 1.5, keine Concerns → `.reduceLoadThisWeek`
- `testMaintainCurrentWhenOnTrack` — onTrack, keine Concerns, kein hohes ACR → `.maintainCurrent`
- `testAllNineTicketScenarios` — parametrisiert über die 9 Ticket-Fälle aus Spec §3.5

### Abnahmekriterien
- `swift build --target DeltiqCore` grün
- Alle 6+ Tests grün
- `IntegratedRunCoachAdvisor.assess()` ist rein deterministisch (gleiche Inputs → gleicher Output)
- Kein SwiftData-Import in den neuen Dateien

### Regressionsrisiken
- **Keine**: Neue Dateien, keine bestehenden Typen verändert
- Einzige Vorsicht: Namespace-Konflikt mit bestehenden Typen in `DeltiqCore` prüfen (`grep -r "IntegratedRunCoach\|CoachingAction\|IntegratedCoachingOutcome" Sources/`)

### Commit
```
feat(cardio): Phase 3A – IntegratedRunCoachAdvisor pure function + types
```

---

## Work Package B — Coaching-Empfehlung Section in `CardioCoachDetailView`

### Ziel
Neue Section in `CardioCoachDetailView` nach `loadSection`, die `IntegratedRunCoachAdvisor.assess()` aufruft und das `IntegratedCoachingOutcome` als lesbaren Text rendert.

### Betroffene Dateien
- `Sources/DeltiqUI/Cardio/CardioCoachDetailView.swift` **(ändern)**
- `Sources/DeltiqUI/DashboardView.swift` **(ändern — Initialisierungsaufruf)**
- `Sources/DeltiqUI/Resources/Localizable.xcstrings` **(neue Keys)**

### Abhängigkeiten
WP-A muss zuerst kompilieren.

### Daten-Zugang (entschieden in Architektur-Review)

`CardioCoachDetailView` hat bereits `@Query allSessions: [WorkoutSession]` und `@Bindable profile`. Folgendes wird ergänzt:

1. **Parameter `raceProgressModel: RaceProgressCardModel?`** — von `DashboardView` übergeben (bereits dort berechnet via `RaceProgressCardModel.make(for: profile, allSessions: completedSessions, now: .now)`)
2. **Parameter `densityAssessment: TrainingDensityAnalyzer.Assessment?`** — von `DashboardView` übergeben (`cachedDensityAssessment` aus Phase 2C, bereits vorhanden)
3. **Parameter `loadTrend: TrainingLoadTrend?`** — NEU, von `DashboardView` übergeben (separates `cachedLoadTrend`; `TrainingLoadTrend` ist NICHT in `TrainingDensityAnalyzer.Assessment` enthalten)
4. **`@Query(filter: #Predicate<TrainingPlan> { $0.isActive == true }) private var activePlans`** — für `planAdjustmentPending = CoachAdjustmentCardModel.make(for: profile, activePlan: ActivePlanResolver.cardioRelevantPlan(among: activePlans)) != nil`
5. **`weeksToRace: Int?`** — lokal berechnet: `Calendar.current.dateComponents([.weekOfYear], from: Date(), to: raceDate).weekOfYear`

**DashboardView-Änderung:** `computeTrainingDensityAssessment()` berechnet `let trend = TrainingLoadTrendAnalyzer.analyze(...)` intern (Zeile 2888), verwirft es aber aktuell. Neu: zusätzlich `cachedLoadTrend = trend` setzen. Dafür in DashboardView:
```swift
@State private var cachedLoadTrend: TrainingLoadTrend?
// In computeTrainingDensityAssessment() nach Zeile 2888:
cachedLoadTrend = trend
```
Dann `CardioCoachDetailView` mit dem neuen Parameter aufrufen: `loadTrend: cachedLoadTrend`.

⚠️ **KRITISCH — `cachedLoadTrend` im frühen Return zurücksetzen:**
`computeTrainingDensityAssessment()` hat einen frühen `guard !activities.isEmpty else { return nil }` (vor der `trend`-Berechnung). Dieser Zweig setzt `cachedDensityAssessment` auf `nil`, aber `cachedLoadTrend` NICHT — ein veralteter Trend bleibt bei nächster Verwendung stehen, wenn alle Sessions gelöscht werden.

**Implementierungsanforderung:** Der frühe-Return-Zweig MUSS explizit beide Caches zurücksetzen:
```swift
private func computeTrainingDensityAssessment() -> TrainingDensityAnalyzer.Assessment? {
    let activities = TrainingActivityExtractor.extract(from: completedSessions)
    guard !activities.isEmpty else {
        cachedLoadTrend = nil  // ← PFLICHT: verhindert veralteten Trend bei leerer Session-Liste
        return nil
    }
    // ... rest der Funktion
    cachedLoadTrend = trend
    return TrainingDensityAnalyzer.analyze(input: input)
}
```
Beide Caches (`cachedDensityAssessment` und `cachedLoadTrend`) müssen bei jedem `.onChange`-Trigger konsistent aktualisiert oder zurückgesetzt werden. Der Setter in `.onChange` überschreibt `cachedDensityAssessment = computeTrainingDensityAssessment()` automatisch mit `nil` wenn die Funktion `nil` zurückgibt — ABER `cachedLoadTrend` muss INNERHALB der Funktion gesetzt werden, damit der Reset vor dem `return nil` passiert.

### Implementierungsdetails

Initialisierungssignatur (neue Parameter am Ende):
```swift
init(
    profile: UserBodyProfile,
    model: CardioFeasibilityCardModel,
    daysSinceLastRunSession: Int?,
    last7DaysRunSessionCount: Int,
    last7DaysRunVolumeKm: Double,
    raceProgressModel: RaceProgressCardModel?,            // NEU
    densityAssessment: TrainingDensityAnalyzer.Assessment?, // NEU
    loadTrend: TrainingLoadTrend?                         // NEU (separat von densityAssessment!)
)
```

Neues ViewBuilder-Property `private var integratedCoachingSection: some View`:
```swift
guard profile.cardioCoachingEnabled else { return AnyView(EmptyView()) }
let weeksToRace = profile.cardioRaceDate.flatMap {
    Calendar.current.dateComponents([.weekOfYear], from: Date(), to: $0).weekOfYear
}
let planAdjustmentPending = ActivePlanResolver.cardioRelevantPlan(among: activePlans)
    .flatMap { CoachAdjustmentCardModel.make(for: profile, activePlan: $0) } != nil
let outcome = IntegratedRunCoachAdvisor.assess(
    raceProgress: raceProgressModel?.assessment,
    loadTrend: loadTrend,                // direkt aus cachedLoadTrend (DashboardView), NICHT aus densityAssessment
    densityAssessment: densityAssessment,
    goal: profile.cardioGoal,
    weeksToRace: weeksToRace,
    planAdjustmentPending: planAdjustmentPending
)
// Render: outcome.primaryAction.localizedTitle + outcome.rationale.localizedText
// Zweite Zeile: outcome.dataQualityIssues (je ein .caption-Text)
```

Section in `body` nach `loadSection`:
```swift
Section(header: Text("cardioCoach.detail.integrated.header", bundle: .module)) {
    integratedCoachingSection
}
```

### Lokalisierungs-Keys (vollständig in WP-E)
```
cardioCoach.detail.integrated.header
integratedCoach.action.maintainCurrent
integratedCoach.action.reduceLoadThisWeek
integratedCoach.action.increaseVolume          ← %d-Platzhalter für Prozentzahl
integratedCoach.action.reassessGoal
integratedCoach.action.planAdjustmentAvailable
integratedCoach.action.buildRunningBase
integratedCoach.action.insufficientData
integratedCoach.rationale.positiveProgressHighLoad
integratedCoach.rationale.positiveProgressStableLoad
integratedCoach.rationale.plateauNearRace
integratedCoach.rationale.goalUnreachable
integratedCoach.rationale.recentGap
integratedCoach.rationale.recoveryNeeded
integratedCoach.rationale.noRunning
integratedCoach.rationale.crossTraining
integratedCoach.rationale.shortHistory
integratedCoach.rationale.planAdjusted
integratedCoach.dataQuality.missingDistance    ← %d-Platzhalter
integratedCoach.dataQuality.ambiguousActivity  ← %d-Platzhalter
integratedCoach.dataQuality.noDuration
integratedCoach.dataQuality.shortHistory       ← %d-Platzhalter
```

### Tests
Kein neuer XCTest für View-Rendering (IntegratedRunCoachAdvisor-Logik durch WP-A abgedeckt). Visuelle Verifikation auf Simulator nach Implementation.

### Abnahmekriterien
- Section erscheint wenn `cardioCoachingEnabled == true`
- Kein Crash wenn `raceProgressModel == nil` oder `densityAssessment == nil`
- `volumeChart` (Zeilen 189–260) unverändert
- Bestehende Sections (`statusSection`, `historicalSection`, `planSection`, `progressSection`, `loadSection`) unberührt
- DashboardView-Aufruf kompiliert mit neuen Parametern

### Regressionsrisiken
- Initialisierungsänderung in `CardioCoachDetailView` → **DashboardView-Aufrufer muss angepasst werden** (einziger Aufrufer; in `DashboardView` nach `model: CardioFeasibilityCardModel` Berechnung)
- `volumeChart` arbeitet mit `profile.weeklyBaseVolumeKm` — NICHT entfernen, NICHT duplizieren

### Commit
```
feat(cardio): Phase 3B – integrated coaching recommendation in CardioCoachDetailView
```

---

## Work Package C — Handlungsempfehlungen in `RaceProgressDetailView`

### Ziel
Pro Concern eine zweite Textzeile mit konkreter Handlungsempfehlung (kein neuer Core-Typ — reine String-Lokalisierung in der View).

### Betroffene Dateien
- `Sources/DeltiqUI/Cardio/RaceProgressDetailView.swift` **(ändern)**
- `Sources/DeltiqUI/Resources/Localizable.xcstrings` **(neue Keys)**

### Abhängigkeiten
Keine (unabhängig von WP-A und WP-B).

### Implementierungsdetails

Neue `private func recommendation(for concern: RaceProgressAssessment.Concern) -> String`:
```swift
switch concern {
case .loadIncreasedTooFast:
    return String(localized: "raceProgress.recommendation.loadIncreasedTooFast", bundle: .module)
case .insufficientRecovery:
    return String(localized: "raceProgress.recommendation.insufficientRecovery", bundle: .module)
case .volumePlateau:
    return String(localized: "raceProgress.recommendation.volumePlateau", bundle: .module)
case .goalLikelyUnrealistic:
    return String(localized: "raceProgress.recommendation.goalLikelyUnrealistic", bundle: .module)
case .recentTrainingGap:
    return String(localized: "raceProgress.recommendation.recentTrainingGap", bundle: .module)
}
```

In `concernsSection` pro Concern-Zeile nach dem Concern-Text:
```swift
Text(recommendation(for: concern))
    .font(.caption)
    .foregroundStyle(.secondary)
```

### Lokalisierungs-Keys
```
raceProgress.recommendation.loadIncreasedTooFast   (5 Keys)
raceProgress.recommendation.insufficientRecovery
raceProgress.recommendation.volumePlateau
raceProgress.recommendation.goalLikelyUnrealistic
raceProgress.recommendation.recentTrainingGap
```

**Formulierungsregeln** (aus Spec §3.4 und §8):
- Keine medizinischen Formulierungen (nicht: "Verletzungsrisiko")
- Konkret und handlungsorientiert ("Reduziere diesen Woche die Laufdistanz um 10–15 %")
- Gleich kurz in DE, EN, TR

### Tests
**Datei**: `Tests/DeltiqCoreTests/RaceProgressRecommendationTests.swift` (optional — Ruling: da reine String-Lokalisierung in der View, kein Core-Test erforderlich; dokumentiert im Ledger)

Wenn Test erstellt: `testRecommendationNonNilForAllConcerns` — 5 Concern-Cases, je ein non-empty String.

### Abnahmekriterien
- Für jeden der 5 Concerns erscheint eine zweite Zeile in der Detail-View
- Keine Leerzeile bei Concerns ohne Mapping (exhaustive switch)
- `swift build --target DeltiqCore` grün

### Regressionsrisiken
- `concernsSection` ist bestehend — keine anderen Elemente berühren
- `.noHeartRateData` ist **kein** Concern, gehört zu `.weeklyFlags` — nicht in den switch aufnehmen

### Commit
```
feat(cardio): Phase 3C – actionable recommendations in RaceProgressDetailView
```

---

## Work Package D — Erstaktivierungs-UX runCoachCard

### Ziel
Beim Aktivieren von `cardioCoachingEnabled` (AUS → EIN) → `runCoachCard` an Position 1 im Widget-Array, falls nicht bereits in top-3.

### Betroffene Dateien
- `Sources/DeltiqUI/Settings/CardioGoalEditorView.swift` **(ändern — `save()`)**

**Nicht ProfileEditorView**: `cardioCoachingEnabled` wird ausschließlich in `CardioGoalEditorView.save()` gesetzt (via `profile.setEnduranceModality(draftEnduranceModality, runCoachEnabled: draftCardioCoachingEnabled)`). Ein `.onChange` in `ProfileEditorView` würde erst nach Sheet-Dismiss feuern und ist anfälliger.

### Abhängigkeiten
Keine (unabhängig von WP-A, B, C).

### Implementierungsdetails

In `CardioGoalEditorView.save()`, **nach** erfolgreichem `modelContext.save()`, **vor** den Folge-Calls (`planRequiringAdjustment` etc.):

```swift
// Nach try modelContext.save(), vor dismiss()/showingAdjustmentPreview
let wasActivated = !originalCardioCoachingEnabled && draftCardioCoachingEnabled
if wasActivated {
    var ws = profile.activeDashboardWidgets
    if !ws.prefix(3).contains(.runCoachCard) {
        ws.removeAll { $0 == .runCoachCard }
        ws.insert(.runCoachCard, at: min(1, ws.count))
        profile.activeDashboardWidgets = ws
        // kein separates modelContext.save() – anschließende Interaktionen persistieren ws
    }
}
```

`originalCardioCoachingEnabled` = Snapshot-Variable aus dem bereits bestehenden Rollback-Muster (Zeile 227: `let originalCardioCoachingEnabled = profile.cardioCoachingEnabled`).

**Verhalten:**
- AUS → EIN, Karte nicht in top-3: Karte zu Index 1 ✓
- AUS → EIN, Karte bereits in top-3: keine Mutation ✓
- EIN → AUS (Deaktivierungs-Pfad, Zeile 149): `wasActivated` = false → keine Mutation ✓
- EIN → EIN (Ziel-/Datumsänderung, kein Coaching-Toggle): `wasActivated` = false → keine Mutation ✓

**Shortcut**: Ohne neues SwiftData-Feld (`wasRunCoachCardEverPositioned: Bool`) kann Phase 3 "Erstaktivierung" nicht von "Re-Aktivierung nach manueller Kartenverschiebung in pos 4+" trennen. Folge: wer Karte auf pos 5 schiebt, deaktiviert und re-aktiviert, sieht sie erneut an pos 2. Edge case — akzeptiert. Upgrade: neues Bool in `UserBodyProfile` (Phase 4).

**Onboarding-Pfad**: `OnboardingView` und `PlanBuilderView` setzen `cardioCoachingEnabled` separat. Sie sind NICHT von dieser Änderung betroffen. Die Karte erscheint dort an ihrer Standardposition 2 (defaultOrder), die bereits in top-3 liegt — kein Handlungsbedarf.

### Tests
`originalCardioCoachingEnabled` und `draftCardioCoachingEnabled` sind in `save()` bereits lokale Variablen → Logik ist in-line testbar durch manuelle Verifikation auf Simulator:

- `[.nextWorkout, .coachingInsight, .weeklyVolume]` + coach AUS→EIN → `[.nextWorkout, .runCoachCard, .coachingInsight, .weeklyVolume]`
- `[.runCoachCard, .nextWorkout]` + coach AUS→EIN → unverändert (guard feuert)
- `[]` + coach AUS→EIN → `[.runCoachCard]`
- coach EIN→AUS → kein Widget-Array-Change

### Abnahmekriterien
- Kein Duplikat von `runCoachCard` im Array
- Widget an Index 1 (oder 0 bei leerem Array)
- Deaktivierung: kein Widget-Array-Change
- `swift build --target DeltiqCore` grün

### Regressionsrisiken
- `save()` hat komplexes Rollback-Muster — `wasActivated`-Block nur nach `try modelContext.save()`, niemals im Rollback-Pfad (Zeile 255 ff.) 
- Kein Konflikt mit `showingAdjustmentPreview`-Flow der nach demselben Save startet

### Commit
```
feat(cardio): Phase 3D – auto-position runCoachCard on coaching enable
```

---

## Work Package E — Lokalisierung (DE/EN/TR)

### Ziel
Alle neuen Lokalisierungs-Keys für WP-B, WP-C und eventuelle neue WP-A-Keys vollständig in DE, EN und TR eintragen.

### Betroffene Dateien
- `Sources/DeltiqUI/Resources/Localizable.xcstrings` **(ändern)**

### Abhängigkeiten
WP-B und WP-C müssen zuerst festlegen, welche Keys sie verwenden.

### Vollständige Key-Liste

**Aus WP-C (5 Keys × 3 Sprachen = 15 Einträge):**
```
raceProgress.recommendation.loadIncreasedTooFast
raceProgress.recommendation.insufficientRecovery
raceProgress.recommendation.volumePlateau
raceProgress.recommendation.goalLikelyUnrealistic
raceProgress.recommendation.recentTrainingGap
```

**Aus WP-B (16+ Keys × 3 Sprachen):**
```
integratedCoach.section.recommendation
integratedCoach.action.maintainCurrent
integratedCoach.action.reduceLoadThisWeek
integratedCoach.action.increaseWeeklyVolume
integratedCoach.action.reassessGoal
integratedCoach.action.planAdjustmentAvailable
integratedCoach.action.buildRunningBase
integratedCoach.action.insufficientData
integratedCoach.rationale.positiveProgressHighLoad    ← war fälschlich "highACR"
integratedCoach.rationale.positiveProgressStableLoad  ← war fälschlich "onTrack"
integratedCoach.rationale.plateauNearRace             ← war fälschlich "volumePlateau"
integratedCoach.rationale.goalLikelyUnreachable       ← war fälschlich "goalUnrealistic"
integratedCoach.rationale.recentGapDetected           ← war fälschlich "recentGap"
integratedCoach.rationale.recoveryNeeded              ← war fälschlich "insufficientRecovery"
integratedCoach.rationale.noRunningData               ← war fälschlich "noRunData"
integratedCoach.rationale.crossTrainingOnly
integratedCoach.rationale.shortHistory
integratedCoach.rationale.planJustAdjusted            ← war fälschlich "planAdjusted"
```

**Formulierungsbeispiele (DE):**
- `raceProgress.recommendation.loadIncreasedTooFast`: "Reduziere diese Woche dein Laufvolumen um 10–15 %. Dein Körper braucht etwas mehr Erholungszeit."
- `raceProgress.recommendation.insufficientRecovery`: "Plane zwischen deinen Laufeinheiten mindestens einen Ruhetag ein."
- `raceProgress.recommendation.volumePlateau`: "Steigere dein Wochenvolumen um ca. 10 % — kleine, regelmäßige Erhöhungen bringen dich deinem Ziel näher."
- `raceProgress.recommendation.goalLikelyUnrealistic`: "Prüfe, ob dein Ziel noch erreichbar ist — eine Anpassung jetzt spart später Frustration."
- `raceProgress.recommendation.recentTrainingGap`: "Starte mit einer leichten Woche und baue dein Volumen schrittweise wieder auf."
- `integratedCoach.action.maintainCurrent`: "Du bist auf Kurs — weiter so."
- `integratedCoach.action.reduceLoadThisWeek`: "Diese Woche etwas kürzertreten."
- `integratedCoach.action.increaseWeeklyVolume`: "Wochenvolumen moderat erhöhen."
- `integratedCoach.action.reassessGoal`: "Ziel überprüfen."
- `integratedCoach.action.planAdjustmentAvailable`: "Trainingsplan-Anpassung verfügbar."
- `integratedCoach.action.buildRunningBase`: "Laufbasis aufbauen."
- `integratedCoach.action.insufficientData`: "Zu wenig Daten für eine Empfehlung."

### Vorgehen
`.scripts/patch_xcstrings.py`-Pattern aus Phase 2C/2D als Vorlage; oder direkt im JSON editieren (xcstrings-Format kennt die Implementierung aus vorherigen Phasen).

### Abnahmekriterien
- Alle Keys vorhanden in DE, EN, TR
- `extractStrings`-Lauf (oder `grep` auf Key-Namen) findet keine fehlenden Keys
- Keine `%@`-Platzhalter ohne entsprechenden `.formatted`-Aufruf in der View

### Commit
```
i18n(cardio): Phase 3 – add integrated coaching and recommendation strings (DE/EN/TR)
```

---

## Finale Review

Nach WP-E: Code Review über Branch `claude/great-dewdney-af8974` von `main` aus. Schwerpunkte:

1. **Keine medizinischen Formulierungen** in Recommendation-Strings (WP-C, WP-E)
2. **IntegratedRunCoachAdvisor ist rein deterministisch** — kein `Date()`, kein `UUID()` intern (WP-A)
3. **WP-B rendert leer bei fehlendem Renndatum** — kein Absturz, keine Placeholder-UI
4. **Widget-Mutation nur bei Einschalten** — Ausschalten ändert `activeDashboardWidgets` nicht (WP-D)
5. **Kein Duplikat von `runCoachCard`** im Widget-Array nach mehrfachem Toggle (WP-D)
6. **`volumeChart` in CardioCoachDetailView unverändert** — WP-B fügt nur eine neue Section hinzu
7. **ACR-Schwellwert 1.5 konsistent** mit Spec §3.3 — nicht 1.2 (isVolumeSpike) verwechseln
8. **`currentWeeklyVolume`** stammt aus `series.suffix(2)` Mittelwert, nicht `profile.weeklyBaseVolumeKm`
9. **Alle 5 Concern-Cases exhaustiv** im Switch (WP-C) — keine Default-Klausel die Fälle verschluckt
10. **xcstrings-Format korrekt** — kein YAML/JSON-Syntaxfehler, keine fehlenden Sprachen (WP-E)

---

## Test-Matrix

| Test | Datei | Erwartet |
|------|-------|----------|
| `testInsufficientDataWhenBothNil` | DeltiqCoreTests/IntegratedRunCoachAdvisorTests | `.insufficientData` |
| `testPlanAdjustmentPriorityOverConcerns` | DeltiqCoreTests/IntegratedRunCoachAdvisorTests | `.planAdjustmentAvailable` |
| `testGoalUnrealisticBeforeGap` | DeltiqCoreTests/IntegratedRunCoachAdvisorTests | `.reassessGoal` |
| `testLoadReductionFromACR` | DeltiqCoreTests/IntegratedRunCoachAdvisorTests | `.reduceLoadThisWeek` |
| `testMaintainCurrentWhenOnTrack` | DeltiqCoreTests/IntegratedRunCoachAdvisorTests | `.maintainCurrent` |
| `testAllNineTicketScenarios` | DeltiqCoreTests/IntegratedRunCoachAdvisorTests | je 1 Action |
| `testRecommendationNonNilForAllConcerns` | optional/inline | 5/5 non-empty Strings |

---

## Commit-Folge

```
feat(cardio): Phase 3A – IntegratedRunCoachAdvisor pure function + types
feat(cardio): Phase 3B – integrated coaching recommendation in CardioCoachDetailView
feat(cardio): Phase 3C – actionable recommendations in RaceProgressDetailView
feat(cardio): Phase 3D – auto-position runCoachCard on first coaching enable
i18n(cardio): Phase 3 – add integrated coaching and recommendation strings (DE/EN/TR)
```

---

*STOP — Implementierung erfordert explizite Freigabe durch Atakan.*
