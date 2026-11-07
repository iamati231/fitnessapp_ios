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
        weeksToRace: Int?,   // für Prio 9: volumePlateau-Schwellenwert (< 10 Wochen); via [.weekOfYear], zählt Wochengrenzen
        daysToRace: Int?,    // für Prio 6a: exakte 14-Tage-Grenze; via startOfDay + [.day], DST-sicher (NEU)
        planAdjustmentPending: Bool
    ) -> IntegratedCoachingOutcome
}
```

> ⚠️ **Warum `daysToRace` als separater Parameter:**
> `Calendar.dateComponents([.weekOfYear], from: now, to: raceDate).weekOfYear` zählt **locale-spezifische Wochengrenzen** (nicht Ganzzahl-Division durch 7). Das Ergebnis hängt davon ab, auf welchen Wochentag `now` fällt. Beispiele bei Wochenbeginn Montag:
> - Montag heute: 14 Tage → `weeksToRace = 2`; 15 Tage → `weeksToRace = 2`; 20 Tage → `weeksToRace = 2`; 21 Tage → `weeksToRace = 3` → deckt 0–20 Tage ab
> - Samstag heute: 14 Tage → `weeksToRace = 2`; 15 Tage → `weeksToRace = 2`; **16 Tage → `weeksToRace = 3`** → deckt nur 0–15 Tage ab
>
> Die fachliche Grenze ≤ 14 Tage lässt sich mit `weeksToRace` allein nicht exakt und wochentag-unabhängig abbilden. WP-A muss `daysToRace: Int?` als separaten Parameter entgegennehmen.
>
> **Kalender- und Zeitzonenquelle:** `Calendar.current` — identisch mit dem Muster im gesamten Codebase (u.a. `AbsenceDeload.swift`, `CardioCoachDetailView`, `HealthKitService`). Keine `TimeZone`-Überschreibung.
>
> **Caller-Berechnung** (in `CardioCoachDetailView`, neben der bestehenden `weeksToRace`-Berechnung):
> ```swift
> let cal = Calendar.current
> let daysToRace: Int? = profile.cardioRaceDate.flatMap {
>     let today = cal.startOfDay(for: Date())    // Tagesbeginn lokal, DST-bereinigt
>     let raceDay = cal.startOfDay(for: $0)      // Renntag auf 00:00 normalisiert
>     return cal.dateComponents([.day], from: today, to: raceDay).day
> }.flatMap { $0 >= 0 ? $0 : nil }  // negative Werte (Rennen in der Vergangenheit) = nil
> ```
>
> **Warum `startOfDay`:** Das etablierte Codebase-Muster (`AbsenceDeload.swift:107-111`) normalisiert beide Datumswerte auf `startOfDay`, bevor `dateComponents([.day], ...)` aufgerufen wird. Dadurch:
> - Unterschiedliche Uhrzeiten am selben Kalendertag liefern denselben `daysToRace`-Wert (Uhrzeit-Invarianz)
> - Sommerzeitwechsel (23- oder 25-Stunden-Tage) haben keinen Einfluss — `startOfDay(for:)` gibt den tatsächlichen ersten Moment des Kalendertags zurück
> - Ein Renntag um 06:00 früh und einer um 23:30 abends ergeben für denselben Kalendertag `daysToRace = 0`

### Prioritätsreihenfolge (12 Stufen, oben = höchste Priorität)

| Priorität | Bedingung | Action |
|-----------|-----------|--------|
| 1 | `loadTrend == nil` ODER `dataCompleteness == .insufficient` | `.insufficientData` |
| 2 | Keine Lauf-Sessions (runningSessionCount == 0 letzte 4 Wochen) | `.buildRunningBase` |
| 3 | Nur Cross-Training (`isCrossTrainingOnly` dominant) | `.buildRunningBase` ← **korrigiert** |
| 4 | `planAdjustmentPending == true` | `.planAdjustmentAvailable` |
| 5 | `concerns.contains(.goalLikelyUnrealistic)` | `.reassessGoal` |
| **6a** | `concerns.contains(.recentTrainingGap)` **UND** `daysToRace != nil && daysToRace! <= 14` | `.maintainCurrent` ← **neu** |
| **6b** | `concerns.contains(.recentTrainingGap)` | `.buildRunningBase` ← **korrigiert** |
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

**Prio 6a + 6b — `recentTrainingGap`: Schwellenwert, Wettkampfnähe, unvollständige Wochen:**

**Schwellenwert:** `RaceProgressAssessment.minimumConsecutiveGapWeeksForConcern = 2` (`RaceProgressAssessment.swift:136`). Eine einzige trainingsfreie Woche löst Prio 6 **NICHT** aus. Erst zwei aufeinanderfolgende `.genuineGap`-Wochen aus **abgeschlossenen Kalenderwochen** (`trailingGenuineGapStreak >= 2`) triggern `recentTrainingGap`.

`.genuineGap` entsteht nur, wenn ALLE Zähler null sind (`RaceProgressAssessment.swift:198`):
```swift
// runningSessionCount == 0 && crossTrainingSessionCount == 0
// && strengthSessionCount == 0 && ambiguousCardioSessionCount == 0
return .genuineGap
```
Eine Deload-Woche mit einem einzigen Workout (Kraft oder Rad) → `.strengthOnlyWeek` oder `.crossTrainingOnlyWeek`, KEIN `.genuineGap`.

---

**Problem A — Unvollständige Kalenderwochen: WP-A-Implementierungsanforderung**

`CardioVolumeOverTimeAggregator.aggregate()` erstellt einen Bucket für JEDE Woche im Fenster inklusive der aktuellen laufenden Woche (loop-Invariante, `CardioVolumeOverTimeAggregator.swift:97-98`). Das letzte Element in `series` ist IMMER die aktuelle, noch nicht abgeschlossene Woche. Wenn der Nutzer noch nichts in der laufenden Woche geloggt hat, erscheinen alle Zähler als 0 → `.genuineGap`. Die bestehende Implementierung von `trailingGenuineGapStreak` kennt keinen Unterschied zwischen abgeschlossenen und laufenden Wochen.

**Verbindliche Regel:** Für die Gap-Streak zählen ausschließlich **abgeschlossene** Kalenderwochen. Die aktuelle laufende Woche darf nie als zweite abgeschlossene Gap-Woche zählen.

**WP-A muss `RaceProgressAssessment.Input` erweitern:**
```swift
// Neues Feld in RaceProgressAssessment.Input
/// true, wenn das letzte Element in `weeklySeries` die aktuelle, noch nicht
/// abgeschlossene Kalenderwoche repräsentiert. Immer true wenn Daten aus
/// CardioVolumeOverTimeAggregator.aggregate() stammen (loop-Invariante).
public let isCurrentWeekIncomplete: Bool
```

**WP-A muss `RaceProgressAssessment.assess()` anpassen** (Streak-Berechnung, nicht Display):
```swift
// Aktuelle (unvollständige) Woche aus Gap-Streak ausschließen, wenn sie leer ist
let flagsForStreak: [WeeklyFlag?]
if input.isCurrentWeekIncomplete && flags.last == .genuineGap {
    flagsForStreak = Array(flags.dropLast())
} else {
    // Aktuelle Woche hat Aktivität (kein .genuineGap) → bricht Streak ohnehin
    flagsForStreak = flags
}
let trailingGapStreak = trailingGenuineGapStreak(flagsForStreak)
// assessment.weeklyFlags bleibt = flags (alle Wochen inkl. aktueller, für Display)
```

**WP-A muss `RaceProgressCardModel.make()` anpassen** (Caller):
```swift
let currentWeekStart = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
let isCurrentWeekIncomplete = series.last?.weekStart == currentWeekStart
let assessment = RaceProgressAssessment.assess(.init(
    weeklySeries: series,
    ...,
    isCurrentWeekIncomplete: isCurrentWeekIncomplete,  // NEU
    now: now
))
```

---

**Problem B — Wettkampfnähe: Prio 6a**

Bei Rennen in ≤ 14 Tagen (`daysToRace <= 14`) ist kein sinnvoller Laufbasis-Aufbau mehr möglich. Plötzliche Volumensteigerung kurz vor Wettkampf riskiert Überlastungsverletzungen. Prio 6a greift vor 6b (Renndatum vorhanden und nah):

- **Prio 6a** (`daysToRace != nil && daysToRace! <= 14`): `.maintainCurrent` + `.recentGapDetected` — keine Volumenerhöhung, kein Tapering, keine Aussage über Renntauglichkeit
- **Prio 6b** (kein Rennen oder `daysToRace > 14`): `.buildRunningBase` + `.recentGapDetected` — gradueller Wiederaufbau

**Schwellenwert und Berechnung:** `Calendar.dateComponents([.weekOfYear], ...)` zählt locale-spezifische Wochengrenzen, keine Ganzzahl-Division durch 7. Der bedeckte Bereich für `weeksToRace <= 2` hängt vom Wochentag ab — zwischen 0–15 Tage (Samstag, Wochenbeginn Montag) und 0–20 Tage (Montag, Wochenbeginn Montag). Die exakte 14-Tage-Grenze ist mit `weeksToRace` nicht wochentag-unabhängig abbildbar. WP-A muss deshalb `daysToRace: Int?` mit `startOfDay`-Normalisierung verwenden:

| Abstand | `weeksToRace` (Montag heute, Mo-Start) | `daysToRace` (normalisiert) | Prio 6a mit `daysToRace <= 14` |
|---------|----------------------------------------|----------------------------|-------------------------------|
| Vergangenes Rennen | — | nil (negativ → nil) | nein → Prio 6b ✓ |
| 0 Tage (Renntag) | 0 | 0 | ja ✓ |
| 1 Tag | 0 | 1 | ja ✓ |
| 7 Tage | 1 | 7 | ja ✓ |
| 13 Tage | 1 | 13 | ja ✓ |
| 14 Tage | 2 | 14 | ja ✓ |
| **15 Tage** | **2** | **15** | **nein → Prio 6b ✓** |
| 20 Tage | 2 | 20 | nein → Prio 6b ✓ |
| 21 Tage | 3 | 21 | nein → Prio 6b ✓ |
| Kein Renntag | nil | nil | nein → Prio 6b ✓ |

**Kalender- und Zeitzonenquelle:** `Calendar.current` — locale-aware, Zeitzone des Nutzers, keine `TimeZone`-Überschreibung. Identisch mit `AbsenceDeload.swift`, `HealthKitService` und allen anderen Kalenderberechnungen im Codebase.

**Kalendertagsemantik und `startOfDay`-Normalisierung:** Das etablierte Codebase-Muster (`AbsenceDeload.swift:107-111`) normalisiert beide Datumswerte auf `startOfDay(for:)` vor `dateComponents([.day], ...)`. `startOfDay(for:)` gibt den tatsächlichen ersten Moment des Kalendertags zurück — DST-bereinigt. Damit:

| Szenario | `daysToRace` (mit startOfDay) |
|----------|-------------------------------|
| Jetzt 06:00, Rennen am selben Kalendertag 20:00 | 0 ✓ |
| Jetzt 23:30, Rennen am selben Kalendertag 09:00 | 0 ✓ |
| Jetzt 06:00, Rennen in 14 Kalendertagen 09:00 | 14 ✓ |
| Jetzt 23:30, Rennen in 14 Kalendertagen 09:00 | 14 ✓ |
| Sommerzeitwechsel zwischen heute und Renntag | kein Einfluss — startOfDay ist DST-bereinigt ✓ |

Negative Werte (Rennen in der Vergangenheit) → `nil` im Caller → Prio 6b greift.

**Lokalisierung:** `integratedCoach.action.maintainCurrent` → **"Aktuelles Programm beibehalten."** (war: "Du bist auf Kurs – weiter so." — letzteres ist irreführend bei Prio 6a mit Gap-Erkennung). Kombinierter Text Prio 6a: "Trainingspause erkannt." + "Aktuelles Programm beibehalten."

**Keine neuen `CoachingAction`- oder `CoachingRationale`-Cases erforderlich.** Existierende Typen sind ausreichend.

---

**Datenlücke — Geplante vs. ungeplante Trainingspause:**
Das System kennt keine "geplante Ruhezeit"-Information. Eine Urlaubs-Pause mit null Workouts ist für das System identisch mit einer ungewollten Lücke. Dokumentierte Datenlücke — keine Falschaussage, kein Workaround.

---

**Wechselseitiger Ausschluss: `.recentTrainingGap` und `.insufficientRecovery`**

Diese beiden Concerns sind mit der aktuellen Implementierung **physikalisch nicht gleichzeitig möglich**:

- `.recentTrainingGap` setzt voraus: die letzten ≥ 2 Wochen sind `.genuineGap` → `runningDistanceKm == 0` in der letzten Woche
- `checkRecovery()` hat als erstes Guard-Statement `guard series.last!.runningDistanceKm > 0` (`RaceProgressAssessment.swift:232`) → schlägt bei Gap-Woche sofort fehl → liefert `nil`

**Folge:** Wenn `recentTrainingGap` feuert, kann `insufficientRecovery` niemals gleichzeitig in `concerns` erscheinen. Die Prioritätsreihenfolge Prio 6b vor 7 bleibt trotzdem dokumentiert (defensive Reihenfolge, falls künftige Implementierungsänderungen diese Exklusivität aufheben).

---

**Aktiver Plan vs. ausstehende Plananpassung**

`planAdjustmentPending` ist **NICHT** dasselbe wie „aktiver Plan vorhanden":

```
planAdjustmentPending = (CoachAdjustmentCardModel.make(for: profile, activePlan: plan) != nil)
```

`make()` gibt nur dann non-nil zurück, wenn `ActivePlanResolver.planRequiringAdjustment()` ein Ergebnis liefert — was ausschließlich bei zwei Ereignissen passiert:

1. **Coach-Aktivierung AUS→EIN** (neuer Lauf-Coach-Plan wird benötigt)
2. **Zieländerung** (z.B. Halbmarathon → Marathon — Plan passt nicht mehr zum neuen Ziel)

| Zustand | `planAdjustmentPending` | Prio |
|---------|------------------------|------|
| Kein aktiver Plan | `false` | — (kein Prio-4-Trigger) |
| Aktiver Plan, kein Ereignis | `false` | — (Prio 6b greift bei Gap) |
| Aktiver Plan + Coach gerade aktiviert | `true` | **4** |
| Aktiver Plan + Ziel gerade geändert | `true` | **4** |
| Aktiver Plan + bereits bestätigte Anpassung | `false` (Fingerprint-Match → `make() = nil`) | — (Prio 6b greift bei Gap) |

---

**Testfälle Prio 6a + 6b (am `IntegratedRunCoachAdvisor`, aktualisiert):**

Alle 7 Tagesgrenzen aus dem Ticket plus kombinierte Szenarien:

| Test | Eingabe | Erw. Prio | Erw. Action | Erw. Rationale |
|------|---------|-----------|-------------|----------------|
| `testGap_oneCompleteGapWeek_currentWeekLogged` | 1 abgeschl. genuineGap + akt. Woche mit Lauf | — | `.maintainCurrent` (kein Gap-Concern, Streak = 0) | `.positiveProgressStableLoad` |
| `testGap_twoCompleteGapWeeks_currentWeekEmpty` | 2 abgeschl. Gap + akt. Woche leer | 6b | `.buildRunningBase` | `.recentGapDetected` |
| `testGap_oneCompleteGapWeek_currentWeekEmpty` | 1 abgeschl. Gap + akt. Woche leer | — | kein Gap-Concern (streak = 1 < 2) → `.maintainCurrent` | `.positiveProgressStableLoad` |
| `testGap_currentWeekEmpty_noCompletedGap` | akt. Woche leer, davor Laufwochen | — | kein Gap-Concern (streak = 0) | — |
| `testGap_raceToday_twoCompleteGaps` | 2 abgeschl. Gap + `daysToRace = 0` | **6a** | `.maintainCurrent` | `.recentGapDetected` |
| `testGap_raceIn1Day_twoCompleteGaps` | 2 abgeschl. Gap + `daysToRace = 1` | **6a** | `.maintainCurrent` | `.recentGapDetected` |
| `testGap_raceIn7Days_twoCompleteGaps` | 2 abgeschl. Gap + `daysToRace = 7` | **6a** | `.maintainCurrent` | `.recentGapDetected` |
| `testGap_raceIn14Days_twoCompleteGaps` | 2 abgeschl. Gap + `daysToRace = 14` | **6a** | `.maintainCurrent` | `.recentGapDetected` |
| `testGap_raceIn15Days_twoCompleteGaps` | 2 abgeschl. Gap + `daysToRace = 15` | **6b** | `.buildRunningBase` | `.recentGapDetected` |
| `testGap_raceIn20Days_twoCompleteGaps` | 2 abgeschl. Gap + `daysToRace = 20` | **6b** | `.buildRunningBase` | `.recentGapDetected` |
| `testGap_raceIn21Days_twoCompleteGaps` | 2 abgeschl. Gap + `daysToRace = 21` | **6b** | `.buildRunningBase` | `.recentGapDetected` |
| `testGap_noRaceDate_twoCompleteGaps` | 2 abgeschl. Gap + `daysToRace = nil` | **6b** | `.buildRunningBase` | `.recentGapDetected` |
| `testGap_planAdjustmentPending_twoCompleteGaps` | 2 abgeschl. Gap + `planAdjustmentPending = true` (Coach gerade aktiviert oder Ziel geändert) | **4** | `.planAdjustmentAvailable` | `.planJustAdjusted` |
| `testGap_activePlanNoPendingAdjustment_twoCompleteGaps` | 2 abgeschl. Gap + aktiver Plan + kein Ereignis (`planAdjustmentPending = false`) | **6b** | `.buildRunningBase` | `.recentGapDetected` |
| `testGap_planAlreadyAccepted_twoCompleteGaps` | 2 abgeschl. Gap + Plan vorhanden + Anpassung bereits bestätigt (`planAdjustmentPending = false`, Fingerprint gesetzt) | **6b** | `.buildRunningBase` | `.recentGapDetected` |
| `testGap_recoveryWithRunningLastWeek` | Aktive Laufwoche (kein Gap), Recovery-Concern vorhanden, kein Gap-Concern | **7** | `.reduceLoadThisWeek` | `.recoveryNeeded` |
| `testGap_mixedWeeks_kraftAndCross` | Woche mit Kraft → `.strengthOnlyWeek`; Woche mit Rad → `.crossTrainingOnly` → kein genuineGap | — | kein Gap-Concern | — |

> ⚠️ **`testGap_withRecoveryConcern_twoGaps` ist ein unmögliches Szenario** — wenn `recentTrainingGap` feuert (trailing 2+ Gap-Wochen), ist `series.last.runningDistanceKm == 0`, und `checkRecovery()` liefert nil wegen des ersten Guard-Statements. Diese Kombination kann mit dem bestehenden Code nie eintreten. Der Test wurde durch realistische Szenarien ersetzt.

**Wichtige Invarianten pro Test:**
- `planAdjustmentPending = true` erfordert entweder Coach-Aktivierung AUS→EIN ODER Zieländerung — kein bloßer aktiver Plan
- `isCurrentWeekIncomplete = true` in allen Prod-Szenarien (von `RaceProgressCardModel.make()` berechnet)
- `assessment.weeklyFlags` enthält IMMER alle Wochen inkl. aktueller (Display-Transparenz)
- `daysToRace` und `weeksToRace` werden vom Caller getrennt berechnet — `daysToRace` aus `dateComponents([.day], ...)`, `weeksToRace` aus `dateComponents([.weekOfYear], ...)`

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
5. **`weeksToRace: Int?`** — lokal berechnet: `Calendar.current.dateComponents([.weekOfYear], from: Date(), to: raceDate).weekOfYear` (für Prio 9: volumePlateau-Schwellenwert)
6. **`daysToRace: Int?`** — lokal berechnet mit `startOfDay`-Normalisierung (für Prio 6a: exakte 14-Tage-Grenze — `weeksToRace` allein reicht nicht, da der bedeckte Bereich wochentag-abhängig ist):
   ```swift
   let cal = Calendar.current
   let daysToRace: Int? = profile.cardioRaceDate.flatMap {
       let today = cal.startOfDay(for: Date())
       let raceDay = cal.startOfDay(for: $0)
       return cal.dateComponents([.day], from: today, to: raceDay).day
   }.flatMap { $0 >= 0 ? $0 : nil }
   ```

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
