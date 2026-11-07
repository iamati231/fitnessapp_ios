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

## Offene Entscheidungen (vor WP-A zu klären)

1. **Kombiniertes Assessment sichtbar machen**: Soll `IntegratedCoachingOutcome` in `CardioCoachDetailView` eine neue Section bekommen (WP-B), oder reicht Einzelempfehlung in RaceProgressDetailView (WP-C)?
2. **`cardioJunkMiles` aktivieren**: Ist Phase 3 der richtige Zeitpunkt?
3. **Widget-Repositionierung**: Nur bei Erstaktivierung oder auch bei Re-Aktivierung nach Deaktivierung?

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
| 1 | `raceProgress == nil && loadTrend == nil` | `.insufficientData([.lessThanTwoWeeks])` |
| 2 | Keine Lauf-Sessions (nur Kraft) | `.insufficientData([.noRunningData])` |
| 3 | Nur Cross-Training (`isCrossTrainingOnly`) | `.insufficientData([.crossTrainingOnly])` |
| 4 | `planAdjustmentPending == true` | `.planAdjustmentAvailable` |
| 5 | `concerns.contains(.goalLikelyUnrealistic)` | `.reassessGoal` |
| 6 | `concerns.contains(.recentTrainingGap)` | `.buildRunningBase` |
| 7 | `concerns.contains(.insufficientRecovery)` | `.reduceLoadThisWeek` |
| 8 | `loadTrend.acuteChronicRatio > 1.5` | `.reduceLoadThisWeek` |
| 9 | `concerns.contains(.loadIncreasedTooFast)` | `.reduceLoadThisWeek` |
| 10 | `concerns.contains(.volumePlateau) && weeksToRace < 8` | `.increaseWeeklyVolume(targetPercent: 0.10)` |
| 11 | `concerns.contains(.volumePlateau) && weeksToRace >= 8` | `.increaseWeeklyVolume(targetPercent: 0.08)` |
| 12 | Stabile Lage (Outcome `.onTrack`) | `.maintainCurrent` |

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
- `Sources/DeltiqUI/Resources/Localizable.xcstrings` **(neue Keys)**

### Abhängigkeiten
WP-A muss zuerst kompilieren.

### Implementierungsdetails

Die View braucht Zugang zu:
1. `RaceProgressAssessment.Assessment?` — bereits via `RaceProgressCardModel.assessment` berechenbar (oder direkt vom profil)
2. `TrainingLoadTrend?` — aus `DashboardView.computeTrainingDensityAssessment()` Vorbild; dort ist `TrainingLoadTrendAnalyzer.analyze()` der Einstieg
3. `weeksToRace: Int?` — aus `profile.cardioRaceDate` und `Calendar.current.dateComponents`
4. `planAdjustmentPending: Bool` — aus `profile.hasPendingCoachAdjustment` oder `CoachAdjustmentCardModel != nil`

Neues ViewBuilder-Property `private var integratedCoachingSection: some View`:
```swift
// Guard: mindestens cardioCoachingEnabled
guard profile.cardioCoachingEnabled else { return AnyView(EmptyView()) }
let outcome = IntegratedRunCoachAdvisor.assess(
    raceProgress: /* computed locally */,
    loadTrend: /* computed locally */,
    densityAssessment: /* computed locally */,
    goal: profile.cardioGoal,
    weeksToRace: /* computed locally */,
    planAdjustmentPending: /* computed locally */
)
// Render: CoachingAction.localizedTitle + CoachingRationale.primarySignal
```

**Wichtig**: Die drei Pipelines werden lokal in der View neu berechnet (kein neues State, kein @Query — die View hat `profile` und `allSessions` bereits). Kein neues ObservableObject.

Section in `body`:
```swift
Section(header: Text("integratedCoach.section.recommendation", bundle: .module)) {
    integratedCoachingSection
}
```

### Lokalisierungs-Keys (Subset — vollständig in WP-E)
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

### Tests
Kein neuer XCTest erforderlich (View-Rendering; IntegratedRunCoachAdvisor-Logik durch WP-A abgedeckt). Optional: Screenshot-Test oder SwiftUI Preview.

### Abnahmekriterien
- Section erscheint in `CardioCoachDetailView` wenn `cardioCoachingEnabled == true`
- Bei `cardioCoachingEnabled == false` leer / EmptyView
- Kein Absturz wenn `raceDate == nil` oder `cardioGoal == nil`
- `swift build --target DeltiqCore` und `swift build --target DeltiqUI` (ZIPFoundation-Fehler auf Windows erwartet) grün für Core

### Regressionsrisiken
- `CardioCoachDetailView` ist eine wichtige View — bestehende Sections (`statusSection`, `historicalSection`, `volumeChart`, `planSection`, `progressSection`, `loadSection`) dürfen nicht angetastet werden
- `volumeChart` (Zeilen 189–260) existiert bereits und ruft `weeklyVolumeProjection` auf — NICHT entfernen, NICHT duplizieren

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
Beim Einschalten von `cardioCoachingEnabled` → `runCoachCard` an Position 1 im Widget-Array (hinter dem ersten Widget, d.h. Index 1).

### Betroffene Dateien
- `Sources/DeltiqUI/Settings/ProfileEditorView.swift` **(ändern)**

### Abhängigkeiten
Keine (unabhängig von WP-A, B, C).

### Implementierungsdetails

Inline `.onChange`-Handler in `ProfileEditorView` (kein neuer Export, kein neues StaticFunc):

```swift
.onChange(of: profile.cardioCoachingEnabled) { _, newValue in
    guard newValue else { return }
    var ws = profile.activeDashboardWidgets
    guard !ws.prefix(3).contains(.runCoachCard) else { return }
    ws.removeAll { $0 == .runCoachCard }
    ws.insert(.runCoachCard, at: min(1, ws.count))
    profile.activeDashboardWidgets = ws
}
```

**Verhalten**:
- Einschalten → `runCoachCard` an Position 1 (Duplikat-Schutz: bereits in top-3 → keine Mutation)
- Ausschalten → keine Mutation (Widget bleibt wo es ist; nächste Einschaltung bewegt es wieder)
- Re-Aktivierung nach Deaktivierung → bewegt Karte erneut, falls nicht in top-3 (entspricht Erstaktivierungs-UX)

### Tests
Da die Logik inline ist (kein testbarer Export), als Integration-Kommentar dokumentieren. Falls Extraktion gewünscht, aus `ws`-Mutation eine `static func insertRunCoachCard(into:) -> [DashboardWidgetType]` extrahieren und in `DeltiqDataTests` testen.

Ruling (Ponytail ultra): inline in ProfileEditorView — kein neuer Export, kein neues Symbol. Test-Extraktion nur auf explizite Anfrage.

**Pflicht-Verhalten validieren** (manuell oder Snapshot):
- `[.nextWorkout, .coachingInsight, .weeklyVolume]` + toggle → `[.nextWorkout, .runCoachCard, .coachingInsight, .weeklyVolume]`
- `[.runCoachCard, .nextWorkout]` + toggle → keine Änderung (runCoachCard bereits top-3)
- Leeres Array + toggle → `[.runCoachCard]`

### Abnahmekriterien
- `.onChange`-Handler ist vorhanden
- Kein Duplikat von `runCoachCard` im Array nach Toggle
- Widget an Index 1 (oder Index 0 wenn Array war leer)
- `swift build --target DeltiqCore` grün

### Regressionsrisiken
- `profile.activeDashboardWidgets` wird auch in `DashboardView` und anderen `ProfileEditorView`-Teilen gelesen — keine anderen Widgets dürfen verschoben werden
- `runCoachCard` existiert bereits in `DashboardWidgetType` mit `defaultOrder = 2` — kein Konflikt

### Commit
```
feat(cardio): Phase 3D – auto-position runCoachCard on first coaching enable
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
