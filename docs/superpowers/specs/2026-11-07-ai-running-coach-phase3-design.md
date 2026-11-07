# AI Running Coach – Phase 3: Integrierte Coaching-Entscheidungen und konkrete Handlungsempfehlungen

Datum: 2026-11-07  
Phase: 3 – Integrierte Coaching-Entscheidungen und konkrete Handlungsempfehlungen  
Branch: `claude/great-dewdney-af8974`  
Status: **DESIGN REVIEW — Implementierung ausstehend (Freigabe erforderlich)**

---

## 1. Ziel

Phase 3 verbindet die parallel laufenden Analyse-Pipelines (Race Progress, Training Load/Density) zu einer **einzigen priorisierten Coaching-Aussage** und fügt dort, wo konkrete Handlungen möglich sind, direkt umsetzbare Empfehlungen hinzu — ohne neue SwiftData-Modelle, ohne neue Dashboard-Karte, ohne automatische Planänderungen.

---

## 2. Schritt 1 – Vollständiger Audit

### 2.1 Gelesene Dateien und Kernergebnisse

| Datei | Wichtigste Erkenntnis |
|-------|----------------------|
| `CardioVolumeOverTimeAggregator.swift` | Pure-function-Aggregator, lückenloser Weekly-Bucket; `runningDistanceKm == nil` und `== 0` sind identisch dargestellt (kann nicht unterschieden werden) |
| `RaceProgressDueCalculator.swift` | 14-Tage-Intervall; fingerprint-basiert (Ziel + Renndatum); `state()` ist synchron, `recordAnalysisCompleted` @MainActor |
| `TrainingLoadAggregator.swift` | Wraps CardioVolumeOverTimeAggregator + Kraft-Bucketing; keine zweite Aggregationsschicht |
| `TrainingLoadTrendAnalyzer.swift` | 5 Wochen Vergleichsfenster; ACR auf 4 vollständige Wochen; `durationDataUnavailable` immer in `dataCompleteness`; Lauf und Kraft GETRENNT kombiniert |
| `TrainingActivityExtractor.swift` | SwiftData-Glue: CardioHistoryExtractor für Cardio-Flags + SessionAggregator für Kraft-Sets; selbe `isRealWorkout`-Filterung |
| `PlanParticipationEvaluator.swift` | Rein deterministisch; fixedWeekdays vs. flexibleWeeklyCadence; mehrere `.notReliablyEvaluable`-Fälle; Tag-für-Tag-Verdichtung auf besten Ausgang |
| `MissedRunDayEvaluator.swift` | 14-Tage-Rollfenster; `totalConcludedRunOpportunities` monotoner Zähler gegen "stuck fingerprint"; nur Sessions auf Lauf-Tagen mit Tag-Referenz zählen |
| `ActivePlanResolver.swift` | Deterministische Auswahl: cardioCoach-Plan > einziger Plan > nil; `planRequiringAdjustment()` triggert bei Aktivierung ODER Zieländerung |
| `RaceProgressCardModel.swift` | Brücke HistoryExtractor → Aggregator → Assessment → Karte; `currentWeeklyVolume` = Mittel letzter 2 aktiver Wochen (NICHT profile.weeklyBaseVolumeKm) |
| `MissedRunDaysCardModel.swift` | CoachAdjustmentCardModel als optionaler CTA; nur bei identifizierbaren Lauf-Tagen mit Tag-Referenz |
| `CardioFeasibilityCardModel.swift` | CoachAdjustmentCardModel hat Vorrang vor CardioFeasibilityCardModel bei aktivem Plan |
| `CardioCoachDetailView.swift` | **Kritischer Neufund (siehe 2.2)** |
| `CoachAdjustmentCardModel.swift` | Fingerprint-Idempotenz auf live profile; plan.accept() = einzige Mutations-Stelle |
| `RunCoachPlanAdjustment.swift` | `isEligibleForAdjustment` = fingerprint-Match + sessions.isEmpty; PlanGeneratorInstantiator führt Mutation aus |
| `CardioFeasibilityCalculator.swift` | `weeklyVolumeProjection/chartPoints/chartPhases/ChartPhase` — TEILWEISE tot (s.u.) |
| `CardioHistoryExtractor.swift` | `isCrossTrainingOnly`: cycling unabhängig von running; `hasAmbiguousCardio`: enduranceSportKind == nil |
| `RaceProgressAssessment.swift` | 5 Concern-Fälle; minimumWeeksForVerdict=2; loadIncreaseThreshold=0.25 |
| `CardioCoachingAdvisor.swift` | isVolumeSpike (1.2x); isJunkMiles (20s/km); missedRunWindowDays=14; `cardioJunkMiles` intentional aus Priority-Liste |
| `DashboardView.swift` | 15 Widget-Typen; Priority-Queue für softCoachingContext; `computeTrainingDensityAssessment()` = 2A→2B→2C |
| `RaceProgressDetailView.swift` | Concerns als Text, keine Handlungsempfehlung; kein Chart; .noHeartRateData separat |
| `DashboardWidgetType.swift` | alle 15 Fälle; runCoachCard defaultOrder = Position 2 |

### 2.2 Kritischer Neufund: `volumeChart` bereits implementiert

`CardioCoachDetailView.volumeChart` (Zeilen 189–260) ruft **bereits** `CardioFeasibilityCalculator.weeklyVolumeProjection()` auf und rendert einen BarMark-Chart mit Start/Peak/Wochen-Summary. Die ursprüngliche Einschätzung "dead code" trifft nur auf `chartPoints`, `chartPhases` und `ChartPhase` zu — `weeklyVolumeProjection` selbst ist in Verwendung.

**Auswirkung auf Phase 3**: Task 1 (Volume-Chart hinzufügen) aus dem alten Plan ist **bereits erledigt**. Der Chart ist in `progressSection` → `volumeChart` vorhanden. Freier Implementierungs-Slot für Phase 3.

### 2.3 Lücken-Analyse: Was fehlt

| Lücke | Datei/Stelle | Schwere |
|-------|-------------|---------|
| Keine Handlungsempfehlung pro Concern | `RaceProgressDetailView.concernsSection` | MITTEL — Concern wird gezeigt, aber „was tun?" fehlt |
| Keine Erstaktivierungs-UX runCoachCard | `ProfileEditorView.onChange(of: profile.cardioCoachingEnabled)` | NIEDRIG — Bestandsnutzer sehen Karte nicht oben |
| Race Progress + Training Load getrennt | — kein Kombinier-Schritt — | HOCH — parallele Pipelines ohne Integration |
| chartPoints/chartPhases/ChartPhase tot | `CardioFeasibilityCalculator.swift` | NIEDRIG — existieren, werden nicht benutzt |
| cardioJunkMiles absichtlich inaktiv | `DashboardView.softCoachingContext` | OFFEN — bewusste Entscheidung, kein Bug |

### 2.4 Bestehende Architektur der parallelen Pipelines

Die drei unabhängigen Pipelines laufen heute **ohne Konvergenzpunkt**:

```
Pipeline A — Race Progress
WorkoutSession[] → CardioHistoryExtractor → CardioVolumeOverTimeAggregator
    → RaceProgressAssessment → {outcome, concerns, weeklyFlags}
    → RaceProgressCardModel → raceProgressCard (Dashboard) + RaceProgressDetailView

Pipeline B — Training Load & Density
WorkoutSession[] → TrainingActivityExtractor → TrainingLoadAggregator
    → TrainingLoadTrendAnalyzer → TrainingLoadTrend
    → TrainingDensityAnalyzer → DensityAssessment
    → trainingLoadCard (Dashboard) + detail view

Pipeline C — Feasibility & Plan Adjustment
UserBodyProfile → CardioFeasibilityCalculator.evaluate()
    → CardioFeasibilityCardModel → CardioCoachDetailView + ProfileEditorView
ActivePlanResolver → CoachAdjustmentCardModel → runCoachCard (Dashboard)
MissedRunDayEvaluator → MissedRunDaysCardModel → softCoachingContext
```

**Phase 3 fügt den fehlenden Konvergenzpunkt hinzu** (neue pure function `IntegratedRunCoachAdvisor` in DeltiqCore, kein SwiftData).

---

## 3. Schritt 2 – Vollständiges Design

### 3.1 Vollständiger Datenfluss

```
WorkoutSession[] (SwiftData @Query)
     │
     ├──► CardioHistoryExtractor.loggedSessions()
     │         │
     │         ├──► CardioVolumeOverTimeAggregator.aggregate()
     │         │         │
     │         │         └──► RaceProgressAssessment.assess()
     │         │                   └── Assessment { outcome, concerns, weeklyFlags }
     │         │                                          ↓
     │         └──► (via zip) TrainingActivityExtractor.extract()
     │                         │
     │                         └──► TrainingLoadAggregator.aggregate()
     │                                   │
     │                                   └──► TrainingLoadTrendAnalyzer.analyze()
     │                                             │
     │                                             └──► TrainingDensityAnalyzer (Phase 2C)
     │                                                       └── DensityAssessment
     │
     ├──► CardioFeasibilityCalculator.evaluate()     ← UserBodyProfile
     │         └── CardioFeasibilityCardModel
     │
     ├──► ActivePlanResolver.cardioRelevantPlan()    ← [TrainingPlan]
     │         └──► CoachAdjustmentCardModel.make()
     │
     └──► MissedRunDayEvaluator.evaluate()           ← TrainingPlan
               └── MissedRunDaysCardModel
                                                           ↓
                   ════════════════════════════════════════╧═════════════
                   NEU: IntegratedRunCoachAdvisor.assess(               ║
                       raceProgress: Assessment,                        ║
                       loadTrend: TrainingLoadTrend?,                   ║
                       densityAssessment: TrainingDensityAssessment?,   ║
                       goal: CardioGoal,                                ║
                       weeksToRace: Int?,                               ║
                       planAdjustmentPending: Bool                      ║
                   ) → IntegratedCoachingOutcome                        ║
                   ════════════════════════════════════════════════════════
                                        │
                                        ▼
                              CardioCoachDetailView
                              (neue Section: integrierte Empfehlung)
                                        │
                           falls Plananpassung notwendig:
                                        │
                                        ▼
                              CoachAdjustmentCardModel.accept()
                                        │
                                        ▼
                              RunCoachPlanAdjustment.analyze()
                                        │
                                        ▼
                              PlanGeneratorInstantiator.applyCoachCardioAdjustment()
```

### 3.2 Komponente A: Handlungsempfehlungen pro Concern (RaceProgressDetailView)

**Wo:** `RaceProgressDetailView.concernsSection` — zweite Zeile pro Concern.

**Datenfluss:** Reine View-Funktion, kein neuer Core-Typ.

```swift
private func recommendation(for concern: RaceProgressAssessment.Concern) -> String {
    switch concern {
    case .loadIncreasedTooFast:  → "raceProgress.recommendation.loadIncreasedTooFast"
    case .insufficientRecovery:  → "raceProgress.recommendation.insufficientRecovery"
    case .volumePlateau:         → "raceProgress.recommendation.volumePlateau"
    case .goalLikelyUnrealistic: → "raceProgress.recommendation.goalLikelyUnrealistic"
    case .recentTrainingGap:     → "raceProgress.recommendation.recentTrainingGap"
    }
}
```

**Leitplanke:** Konjunktiv, keine medizinischen Formulierungen, keine Automatik.

**Implementierung:** Pure `switch` in der View, neue Lokalisierungs-Keys. Kein neuer Core-Typ.

### 3.3 Komponente B: Erstaktivierungs-UX runCoachCard

**Wo:** `ProfileEditorView`, `.onChange(of: profile.cardioCoachingEnabled)`.

**Logik:**
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

**Warum kein Rücksetzen beim Ausschalten:** Der Nutzer kontrolliert Widget-Reihenfolge via DashboardSettings — das nächste Einschalten triggert erneut (guard prüft nur "in top 3").

**Implementierung:** Inline in ProfileEditorView, kein neuer Export.

### 3.4 Komponente C: IntegratedRunCoachAdvisor (NEU, DeltiqCore)

**Warum nötig:** Race Progress und Training Load laufen heute unabhängig. Ein Nutzer mit `outcome = .onTrack` und `loadDevelopment = .significantIncrease(.running)` sieht widersprüchliche Signale ohne Priorisierung. Der Advisor vereint beide Pipelines zu **einer** priorisierten Aussage.

**Typ-Signatur (DeltiqCore, pure function):**

```swift
public enum IntegratedRunCoachAdvisor {
    public static func assess(
        raceProgress: RaceProgressAssessment.Assessment,
        loadTrend: TrainingLoadTrend?,
        densityAssessment: TrainingDensityAssessment?,
        goal: CardioGoal,
        weeksToRace: Int?,
        planAdjustmentPending: Bool
    ) -> IntegratedCoachingOutcome
}

public struct IntegratedCoachingOutcome: Sendable, Equatable {
    public let primaryAction: CoachingAction
    public let rationale: CoachingRationale
    public let dataQualityIssues: [DataQualityIssue]
}

public enum CoachingAction: Sendable, Equatable {
    case maintainCurrent
    case reduceLoadThisWeek
    case increaseWeeklyVolume(targetPercent: Double)
    case reassessGoal
    case planAdjustmentAvailable
    case buildRunningBase
    case insufficientData
}

public enum CoachingRationale: Sendable, Equatable {
    case positiveProgressHighLoad     // onTrack + significantIncrease
    case positiveProgressStableLoad   // onTrack + stable
    case plateauNearRace(weeksToRace: Int)
    case goalLikelyUnreachable
    case recentGapDetected
    case recoveryNeeded
    case noRunningData
    case crossTrainingOnly
    case shortHistory
    case planJustAdjusted             // planAdjustmentPending == true
}

public enum DataQualityIssue: Sendable, Equatable {
    case runningDistanceMissing(weekCount: Int)
    case ambiguousActivitiesPresent(weekCount: Int)
    case durationDataUnavailable
    case historyTooShort(weeksAvailable: Int, weeksNeeded: Int)
}
```

**Kein SwiftData**, kein `@MainActor`, keine Lokalisierung im Core-Typ.

**Wo gerendert:** Neue Section in `CardioCoachDetailView` (zwischen `statusSection` und `historicalSection`), die `IntegratedRunCoachAdvisor.assess()` aufruft und `CoachingAction + Rationale` als lokalisierte Textzeile zeigt.

### 3.5 Entscheidungslogik (Prüfreihenfolge)

Reihenfolge ist Priorität — das schwerste Signal gewinnt:

| Priorität | Bedingung | Action | Rationale |
|-----------|-----------|--------|-----------|
| 1 | `loadTrend == nil` ODER `dataCompleteness == .insufficient` | `.insufficientData` | `.shortHistory` |
| 2 | Keine Lauf-Sessions (runningSessionCount == 0 letzte 4 Wochen) | `.buildRunningBase` | `.noRunningData` |
| 3 | Ausschließlich Cross-Training (`isCrossTrainingOnly` dominant) | `.maintainCurrent` | `.crossTrainingOnly` |
| 4 | `planAdjustmentPending == true` | `.planAdjustmentAvailable` | `.planJustAdjusted` |
| 5 | Concern `.goalLikelyUnrealistic` vorhanden | `.reassessGoal` | `.goalLikelyUnreachable` |
| 6 | Concern `.recentTrainingGap` vorhanden | `.reduceLoadThisWeek` | `.recentGapDetected` |
| 7 | Concern `.insufficientRecovery` vorhanden | `.reduceLoadThisWeek` | `.recoveryNeeded` |
| 8 | Concern `.loadIncreasedTooFast` ODER `loadDevelopment == .significantIncrease` | `.reduceLoadThisWeek` | `.positiveProgressHighLoad` oder `.recoveryNeeded` |
| 9 | Concern `.volumePlateau` + `weeksToRace != nil && weeksToRace! < 10` | `.increaseWeeklyVolume(15)` | `.plateauNearRace` |
| 10 | Concern `.volumePlateau` + genug Zeit | `.increaseWeeklyVolume(10)` | `.plateauNearRace` |
| 11 | `outcome == .onTrack` + `loadDevelopment == .stable/.declining` | `.maintainCurrent` | `.positiveProgressStableLoad` |
| 12 | Alles andere | `.maintainCurrent` | `.positiveProgressStableLoad` |

**Datenqualitäts-Issues** werden immer als zweite Zeile angehängt (auch wenn `primaryAction != .insufficientData`).

### 3.6 Fallszenarien aus dem Ticket

| Szenario | Ergebnis |
|----------|---------|
| Positive long-term + short-term high load | Concern `.loadIncreasedTooFast` ODER `loadDevelopment == .significantIncrease` → Prio 8 → `.reduceLoadThisWeek` |
| Stagnating volume near race | Concern `.volumePlateau` + weeksToRace < 10 → Prio 9 → `.increaseWeeklyVolume(15%)` |
| Missing run distance | `dataCompleteness.reasons` enthält `.missingRunningDistance` → `DataQualityIssue.runningDistanceMissing` |
| No run duration | Immer `durationDataUnavailable` → `DataQualityIssue.durationDataUnavailable` (kein blocker, nur info) |
| Strength-only | runningSessionCount == 0 → Prio 2 → `.buildRunningBase` |
| Cross-training only | isCrossTrainingOnly dominant → Prio 3 → `.maintainCurrent` mit `.crossTrainingOnly`-Rationale |
| Unknown activities | `ambiguousCardioSessionCount > 0` → `DataQualityIssue.ambiguousActivitiesPresent` |
| Missing history | `dataCompleteness == .insufficient(shortHistory)` → Prio 1 → `.insufficientData` |
| Goal change HM→Marathon | `ActivePlanResolver.planRequiringAdjustment()` → `CoachAdjustmentCardModel.make()` → `planAdjustmentPending == true` → Prio 4 → `.planAdjustmentAvailable` |

### 3.7 Plan-Integration

**Wie der Coach Plan-Ziel-Mismatch erkennt:**
`ActivePlanResolver.planRequiringAdjustment(coachWasEnabled:coachWillBeEnabled:oldGoal:newGoal:among:)` → löst Anpassungs-Angebot aus, wenn Coach gerade aktiviert ODER Ziel geändert wurde. `IntegratedRunCoachAdvisor` erhält `planAdjustmentPending = (CoachAdjustmentCardModel.make() != nil)` und priorisiert diesen Fall.

**Wie Empfehlung generiert wird:**
`RunCoachPlanAdjustment.analyze(plan:targetGoal:)` → `Analysis` → `CardioAvailability.ready([ids])` oder `noEligibleCardioDay` → Formulierung in `CoachAdjustmentCardModel.verdict`.

**Duplikat-Schutz:**
`CoachAdjustmentCardModel.accept()` prüft `profile.cardioPlanAdjustmentFingerprint != fingerprint` live (nicht auf frozen snapshot) — Doppeltap wird verhindert.

**Plan bleibt unverändert bis Bestätigung:**
Plan-Mutation nur in `CoachAdjustmentCardModel.accept()` oder `CardioFeasibilityCardModel.accept()`. Kein automatisches Auslösen.

**Schutz für abgeschlossene/manuelle Sessions:**
`isEligibleForAdjustment = (fingerprint-Match + sessions.isEmpty)` — nur Wizard-erzeugte, unbearbeitete, session-freie Tage werden angepasst.

**Zieländerung HM→Marathon:**
`ActivePlanResolver.planRequiringAdjustment(coachWasEnabled: true, coachWillBeEnabled: true, oldGoal: .halfMarathon, newGoal: .marathon, among: activePlans)` → liefert plan → `CoachAdjustmentCardModel.make()` → Karte erscheint.

### 3.8 Dashboard-Design

**Keine dritte Coaching-Karte.** Die drei bestehenden Karten (`runCoachCard`, `raceProgressCard`, `trainingLoadCard`) bleiben unverändert in ihrer äußeren Struktur.

**Erweiterung existierender Detail-Views:**
- `CardioCoachDetailView`: neue Section mit `IntegratedRunCoachAdvisor`-Ergebnis (Komponente C)
- `RaceProgressDetailView`: pro Concern eine zweite Zeile mit Handlungsempfehlung (Komponente A)

**Widget-Einstellungen respektiert:**
- Alle drei Cardio-Karten sind über DashboardSettingsView wie gewohnt togglebar/verschiebbar
- Erstaktivierungs-UX (Komponente B) schiebt `runCoachCard` nur in die sichtbare Region, deaktiviert sie nicht

**Kein redundantes Anzeigen** desselben Datums (z.B. kein doppelter Renndatum-Text zwischen `raceProgressCard` und `runCoachCard`-Detail).

---

## 4. Datenmodell-Änderungen

**Keine neuen SwiftData-Felder.**

| Neu | Typ | Modul | SwiftData? |
|-----|-----|-------|-----------|
| `IntegratedRunCoachAdvisor` | `enum` (pure function) | DeltiqCore | Nein |
| `IntegratedCoachingOutcome` | `struct` | DeltiqCore | Nein |
| `CoachingAction` | `enum` | DeltiqCore | Nein |
| `CoachingRationale` | `enum` | DeltiqCore | Nein |
| `DataQualityIssue` | `enum` | DeltiqCore | Nein |

Alle bestehenden Felder werden unverändert genutzt:
- `profile.weeklyBaseVolumeKm` → Chart-Startpunkt (bereits in `volumeChart`)
- `profile.cardioGoal` + `profile.cardioRaceDate` → Projektion (bereits in `volumeChart`)
- `profile.activeDashboardWidgets` → Widget-Reihenfolge (Komponente B mutiert)

---

## 5. Lokalisierungs-Keys (neu)

| Key | DE (Entwurf) |
|-----|--------------|
| `raceProgress.recommendation.loadIncreasedTooFast` | „Nächste Woche das Volumen nicht weiter steigern." |
| `raceProgress.recommendation.insufficientRecovery` | „Zwischen zwei harten Einheiten je einen Ruhetag einplanen." |
| `raceProgress.recommendation.volumePlateau` | „Wochenumfang schrittweise um ~10 % anheben." |
| `raceProgress.recommendation.goalLikelyUnrealistic` | „Erreichbareres Ziel in der Profil-Konfiguration prüfen." |
| `raceProgress.recommendation.recentTrainingGap` | „Erste Woche nach Pause deutlich unter gewohntem Niveau starten." |
| `integratedCoach.action.maintainCurrent` | „Du bist auf Kurs – weiter so." |
| `integratedCoach.action.reduceLoadThisWeek` | „Diese Woche bewusst zurücknehmen." |
| `integratedCoach.action.increaseVolume` | „Wochenumfang um ~%d %% steigern." |
| `integratedCoach.action.reassessGoal` | „Ziel auf Erreichbarkeit überprüfen." |
| `integratedCoach.action.planAdjustmentAvailable` | „Trainingsplan-Anpassung verfügbar." |
| `integratedCoach.action.buildRunningBase` | „Läufe ins Programm bringen." |
| `integratedCoach.action.insufficientData` | „Zu wenig Daten für eine Bewertung." |
| `integratedCoach.rationale.positiveProgressHighLoad` | „Guter Fortschritt, aber diese Woche sehr hohe Belastung." |
| `integratedCoach.rationale.positiveProgressStableLoad` | „Stabile Entwicklung." |
| `integratedCoach.rationale.plateauNearRace` | „Volumen stagniert, Renntag nähert sich." |
| `integratedCoach.rationale.goalUnreachable` | „Ziel mit verbleibender Zeit nicht mehr erreichbar." |
| `integratedCoach.rationale.recentGap` | „Trainingspause erkannt." |
| `integratedCoach.rationale.recoveryNeeded` | „Erholungsbedarf erkannt." |
| `integratedCoach.rationale.noRunning` | „Keine Laufeinheiten in den letzten Wochen." |
| `integratedCoach.rationale.crossTraining` | „Hauptsächlich Cross-Training erkannt." |
| `integratedCoach.rationale.shortHistory` | „Zu wenig Daten für eine Aussage." |
| `integratedCoach.rationale.planAdjusted` | „Plananpassung bereit zur Übernahme." |
| `integratedCoach.dataQuality.missingDistance` | „Laufstrecke für %d Woche(n) nicht erfasst." |
| `integratedCoach.dataQuality.ambiguousActivity` | „%d Woche(n) mit unbekannter Sportart." |
| `integratedCoach.dataQuality.noDuration` | „Trainingsdauer nicht erfasst." |
| `integratedCoach.dataQuality.shortHistory` | „Weniger als %d Wochen Verlauf." |
| `cardioCoach.detail.integrated.header` | „Coaching-Empfehlung" |

---

## 6. Test-Strategie

Alle neuen Core-Typen sind pure functions — vollständig unit-testbar.

| Komponente | Testbar? | Strategie |
|-----------|----------|-----------|
| `IntegratedRunCoachAdvisor.assess()` | ✅ DeltiqCoreTests | 9 Szenarien aus Ticket §6 als parametrisierte Tests |
| `recommendation(for:)` | ✅ | 5 Concern-Cases → non-empty String |
| Erstaktivierungs-UX | ✅ | Extrahierte pure function; given [.nextWorkout, .coachingInsight], toggle → runCoachCard an Position 1 |
| `volumeChart` (bereits vorhanden) | ✅ DeltiqCoreTests vorhanden | Bestehende `CardioFeasibilityCalculatorTests` decken `weeklyVolumeProjection` ab |
| `IntegratedCoachingOutcome`-Rendering | ❌ XCUITest | Kein Präzedenzfall im Repo; visuell auf Device/Simulator |

---

## 7. Kritische Review-Punkte (Self-Check)

1. **Keine medizinischen Formulierungen**: Alle Recommendation-Strings sind im Konjunktiv und bezeichnen Trainingsbelastung, keine Körperzustände.
2. **Kein neues SwiftData-Feld**: `IntegratedRunCoachAdvisor` nimmt existierende Typen — `RaceProgressAssessment.Assessment`, `TrainingLoadTrend`, `TrainingDensityAssessment` — als pure-function-Input.
3. **Keine dritte Dashboard-Karte**: Der Advisor-Output ist eine neue Section in `CardioCoachDetailView`, kein neuer `DashboardWidgetType`-Fall.
4. **Reihenfolge der Entscheidungsregeln ist deterministisch und dokumentiert**: 12 Prioritätsstufen, keine floating-point-Vergleiche ohne Schwelle, keine Array-reihenfolge-abhängige Wahl.
5. **Plan unverändert bis Nutzerbestätigung**: `IntegratedRunCoachAdvisor` erzeugt KEINE Plan-Mutation — er hebt nur hervor, dass `CoachAdjustmentCardModel` aktiv ist.
6. **cardioJunkMiles bleibt inaktiv**: Absichtlich weiterhin nicht in der Priority-Liste; Phase 3 ändert das nicht.
7. **`chartPoints/chartPhases/ChartPhase` bleiben tot**: Sie werden in Phase 3 nicht verwendet; `volumeChart` arbeitet mit dem vollen `weeklyVolumeProjection`-Array ohne Sampling.
8. **Datenqualitäts-Issues blockieren nicht**: Ein `durationDataUnavailable`-Issue verhindert keine `primaryAction` — es wird als informativer Zusatz angehängt.
9. **Fingerprint-Idempotenz bleibt gewahrt**: `CoachAdjustmentCardModel.accept()` und `CardioFeasibilityCardModel.accept()` werden nicht verändert.
10. **PR #4 bleibt ungemergt**: Kein Merge, kein Phase-4-Start.

---

## 8. Abgrenzung zu Phase 4

Phase 3 schließt explizit aus:
- Keine KI-generierten personalisierten Pläne
- Kein Backend / Server-side Coaching
- Kein Push-Notification-Trigger
- Kein pace-adjustment basierend auf Herzfrequenz-Daten (HFmax-basierter Pace existiert, aber keine Ziel-Anpassung)
- Keine Verletzungsprognosen
- Keine Integration von HealthKit-Herzfrequenz-Daten (Phase 1 hat `averageHeartRateBpm: nil` als Platzhalter)
- Kein aktivieren von `cardioJunkMiles`

---

## 9. Offene Fragen vor Implementierung

1. **Schwelle für `increaseWeeklyVolume`**: Ticket-Beispiel nennt 10 % und 15 %. Exakte Zahlen per Fallunterscheidung oder dynamisch aus `weeksToRace` berechnen?
2. **`cardioJunkMiles` aktivieren in Phase 3?**: Advisor `isJunkMiles` ist implementiert, `cardioJunkMiles` CoachingContext existiert — bewusst inaktiv. Bleibt Phase 3 dabei?
3. **Widget-Repositionierung**: Nur beim ersten Einschalten oder bei jedem Einschalten (guard "in top 3" vs. `wasEverEnabled`-Flag)?

---

*Phase 3 Schritt 1 (Audit) und Schritt 2 (Design Review) abgeschlossen. Implementierung (Schritt 3) erfordert explizite Freigabe.*
