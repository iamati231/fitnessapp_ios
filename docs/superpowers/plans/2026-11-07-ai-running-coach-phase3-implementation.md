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
public enum CoachingAction: Equatable {
    case maintainCurrent
    case reduceLoadThisWeek
    case increaseWeeklyVolume(targetPercent: Double)
    case reassessGoal
    case planAdjustmentAvailable
    case buildRunningBase
    case insufficientData(reasons: [DataQualityIssue])
}

public enum DataQualityIssue: String, CaseIterable {
    case noRunningData
    case crossTrainingOnly
    case lessThanTwoWeeks
    case durationUnavailable
    case noGoalSet
}

public struct CoachingRationale: Equatable {
    public let primarySignal: String  // Lokalisierungs-Key
    public let supportingFactors: [String]  // Lokalisierungs-Keys
    public let dataQualityIssues: [DataQualityIssue]
}

public struct IntegratedCoachingOutcome: Equatable {
    public let action: CoachingAction
    public let rationale: CoachingRationale
    public let confidence: Double  // 0.0–1.0
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
2. **Parameter `densityAssessment: TrainingDensityAssessment?`** — von `DashboardView` übergeben (`cachedDensityAssessment` aus Phase 2C, bereits vorhanden)
3. **`@Query(filter: #Predicate<TrainingPlan> { $0.isActive == true }) private var activePlans`** — für `planAdjustmentPending = CoachAdjustmentCardModel.make(for: profile, activePlan: ActivePlanResolver.cardioRelevantPlan(among: activePlans)) != nil`
4. **`weeksToRace: Int?`** — lokal berechnet: `Calendar.current.dateComponents([.weekOfYear], from: Date(), to: raceDate).weekOfYear`

### Implementierungsdetails

Initialisierungssignatur (neue Parameter am Ende):
```swift
init(
    profile: UserBodyProfile,
    model: CardioFeasibilityCardModel,
    daysSinceLastRunSession: Int?,
    last7DaysRunSessionCount: Int,
    last7DaysRunVolumeKm: Double,
    raceProgressModel: RaceProgressCardModel?,       // NEU
    densityAssessment: TrainingDensityAssessment?    // NEU
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
    loadTrend: densityAssessment.flatMap { ... },   // aus DensityAssessment
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
integratedCoach.rationale.highACR
integratedCoach.rationale.goalUnrealistic
integratedCoach.rationale.recentGap
integratedCoach.rationale.insufficientRecovery
integratedCoach.rationale.volumePlateau
integratedCoach.rationale.onTrack
integratedCoach.rationale.noRunData
integratedCoach.rationale.crossTrainingOnly
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
