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

> ⚠️ **Implementierungsort korrigiert in §9 Entscheidung C:** `cardioCoachingEnabled` wird ausschließlich in `CardioGoalEditorView.save()` gesetzt; ein `ProfileEditorView.onChange` ist anfällig und feuert erst nach Sheet-Dismiss. Maßgeblich ist §9, nicht dieser Abschnitt.

**Wo (überholt):** ~~`ProfileEditorView`, `.onChange(of: profile.cardioCoachingEnabled)`~~ → **`CardioGoalEditorView.save()` (s. §9)**.

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

> ⚠️ **Diese Tabelle enthält Vorfassungswerte für Prio 3 und Prio 6** — die korrigierten Werte stehen in **§10**. Für die Implementierung ist §10 maßgeblich.

Reihenfolge ist Priorität — das schwerste Signal gewinnt:

| Priorität | Bedingung | Action | Rationale |
|-----------|-----------|--------|-----------|
| 1 | `loadTrend == nil` ODER `dataCompleteness == .insufficient` | `.insufficientData` | `.shortHistory` |
| 2 | Keine Lauf-Sessions (runningSessionCount == 0 letzte 4 Wochen) | `.buildRunningBase` | `.noRunningData` |
| 3 | Ausschließlich Cross-Training (`isCrossTrainingOnly` dominant) | ~~`.maintainCurrent`~~ → **`.buildRunningBase`** (s. §10) | `.crossTrainingOnly` |
| 4 | `planAdjustmentPending == true` | `.planAdjustmentAvailable` | `.planJustAdjusted` |
| 5 | Concern `.goalLikelyUnrealistic` vorhanden | `.reassessGoal` | `.goalLikelyUnreachable` |
| 6 | Concern `.recentTrainingGap` vorhanden | ~~`.reduceLoadThisWeek`~~ → **`.buildRunningBase`** (s. §10) | `.recentGapDetected` |
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
| Cross-training only | isCrossTrainingOnly dominant → Prio 3 → `.buildRunningBase` mit `.crossTrainingOnly`-Rationale (s. §10) |
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

## 9. Architektur-Entscheidungen (Phase-3-Review, 2026-11-07)

### Entscheidung A: Platzierung von `IntegratedCoachingOutcome`

**Entscheid: `CardioCoachDetailView`** (neue Section nach `loadSection`)

Begründung: Die integrierte Bewertung verbindet Wettkampffortschritt, Belastung und Regeneration — das ist die Kerninformation der zentralen Coaching-Detailansicht. `RaceProgressDetailView` bleibt auf Concern-spezifische Details fokussiert; keine Doppeldarstellung.

Daten-Zugang in `CardioCoachDetailView`:
- `allSessions: [WorkoutSession]` — bereits via `@Query` vorhanden ✓
- `profile: UserBodyProfile` — bereits `@Bindable` vorhanden ✓
- **NEU**: Parameter `raceProgressModel: RaceProgressCardModel?` von DashboardView (bereits dort berechnet — keine Doppel-Aggregation)
- **NEU**: Parameter `densityAssessment: TrainingDensityAssessment?` von DashboardView (`cachedDensityAssessment` aus Phase 2C — bereits vorhanden)
- **NEU**: `@Query(filter: #Predicate<TrainingPlan> { $0.isActive == true }) private var activePlans` — für `planAdjustmentPending` via `CoachAdjustmentCardModel.make(for:activePlan:) != nil`

WP-B muss die `CardioCoachDetailView`-Initialisierung erweitern und alle Aufrufer (primär `DashboardView`) anpassen.

### Entscheidung B: `cardioJunkMiles` aktivieren?

**Entscheid: NEIN — bleibt deaktiviert, Phase 4.**

Drei harte Blocker:
1. **Kein per-Trainingstag-Zieltempo**: `PlanGenerator.cardioCandidates` setzt `targetDistanceKm` NIE → `isJunkMiles(actualPaceMinPerKm:targetPaceMinPerKm:)` hat keinen validen Input
2. **Dauer nicht erfasst**: `durationDataUnavailable` = dauernd in `dataCompleteness` → Tempo aus Distanz/Dauer nicht berechenbar
3. **Kein Profil-weites Referenztempo**: `current5kReferenceSeconds` + Pace-Zonen = Phase-1-Prerequisite, noch nicht implementiert

Fachliches Risiko: Lockere Grundlagenläufe (easy pace) sind intentional langsam — sie würden systematisch als "Junk Miles" bewertet, auch wenn sie trainingsplanerisch korrekt sind. Das führt zu falschen Empfehlungen.

Vorbedingung für Re-Aktivierung (Phase 4): `current5kReferenceSeconds` + personalisierte Pace-Zonen müssen vorliegen; `PlanGenerator` muss `targetPaceMinPerKm` pro Lauf-Tag setzen.

### Entscheidung C: `runCoachCard`-Repositionierung

**Entscheid: Bei jeder Aktivierung von AUS auf EIN, mit top-3-Guard.**

Implementierungsort: `CardioGoalEditorView.save()` — nicht `ProfileEditorView.onChange` (da `cardioCoachingEnabled` nur über den expliziten Save-Flow in `CardioGoalEditorView` oder den Deaktivierungs-Button mutiert wird).

```swift
// In save(), nach erfolgreichem modelContext.save(), vor dismiss()
let wasOff = originalCardioCoachingEnabled == false
let isNowOn = draftCardioCoachingEnabled == true
if wasOff && isNowOn {
    var ws = profile.activeDashboardWidgets
    guard !ws.prefix(3).contains(.runCoachCard) else { return }
    ws.removeAll { $0 == .runCoachCard }
    ws.insert(.runCoachCard, at: min(1, ws.count))
    profile.activeDashboardWidgets = ws
    // kein separates modelContext.save() – der äußere Save ist bereits durch
}
```

Shortcut (dokumentiert): Ohne neues SwiftData-Feld kann Phase 3 nicht zwischen "echtem Erststart" und "Re-Aktivierung nach manueller Kartenverschiebung in pos 4+" unterscheiden. Folge: wer die Karte auf Position 5 schiebt, deaktiviert und wieder aktiviert, sieht sie erneut an Position 2. Wahrscheinlichkeit: gering. Upgrade: neues Bool `wasRunCoachCardEverPositioned` in `UserBodyProfile` (Phase 4).

Deaktivierung → keine Mutation (guard `newValue else { return }` greift).

### Entscheidung D: Volumen-Schwellenwerte für `increaseWeeklyVolume`

**Entscheid: Feste Werte, Fallunterscheidung nach `weeksToRace`.**

- `weeksToRace < 10`: `targetPercent = 0.15` (15 % — wenig Zeit, aggressiver)
- `weeksToRace >= 10`: `targetPercent = 0.10` (10 % — genug Zeit, konservativer)
- `weeksToRace == nil` (kein Renndatum): `targetPercent = 0.10` (Fallback konservativ)

---

## 10. Korrigierte Entscheidungslogik

Die ursprüngliche Prioritätstabelle aus §3.5 enthielt zwei Fehler, die hier korrigiert werden:

| Priorität | Bedingung | Action (KORRIGIERT) | Rationale |
|-----------|-----------|---------------------|-----------|
| 1 | `loadTrend == nil` ODER `dataCompleteness == .insufficient` | `.insufficientData` | `.shortHistory` |
| 2 | Keine Lauf-Sessions (runningSessionCount == 0 letzte 4 Wochen) | `.buildRunningBase` | `.noRunningData` |
| 3 | Ausschließlich Cross-Training (`isCrossTrainingOnly` dominant) | ~~`.maintainCurrent`~~ → **`.buildRunningBase`** | `.crossTrainingOnly` |
| 4 | `planAdjustmentPending == true` | `.planAdjustmentAvailable` | `.planJustAdjusted` |
| 5 | Concern `.goalLikelyUnrealistic` vorhanden | `.reassessGoal` | `.goalLikelyUnreachable` |
| **6a** | Concern `.recentTrainingGap` vorhanden **UND** `weeksToRace != nil && weeksToRace! <= 2` | `.maintainCurrent` | `.recentGapDetected` |
| **6b** | Concern `.recentTrainingGap` vorhanden | ~~`.reduceLoadThisWeek`~~ → **`.buildRunningBase`** | `.recentGapDetected` |
| 7 | Concern `.insufficientRecovery` vorhanden | `.reduceLoadThisWeek` | `.recoveryNeeded` |
| 8 | Concern `.loadIncreasedTooFast` ODER `loadDevelopment == .significantIncrease` | `.reduceLoadThisWeek` | `.positiveProgressHighLoad` oder `.recoveryNeeded` |
| 9 | Concern `.volumePlateau` + `weeksToRace < 10` | `.increaseWeeklyVolume(0.15)` | `.plateauNearRace` |
| 10 | Concern `.volumePlateau` + `weeksToRace >= 10 / nil` | `.increaseWeeklyVolume(0.10)` | `.plateauNearRace` |
| 11 | `outcome == .onTrack` + `loadDevelopment == .stable/.declining` | `.maintainCurrent` | `.positiveProgressStableLoad` |
| 12 | Alles andere | `.maintainCurrent` | `.positiveProgressStableLoad` |

**Korrektur-Begründungen:**
- **Prio 3**: Ein Läufer/eine Läuferin mit Renndatum, der/die nur Cross-Training (Radfahren) absolviert, braucht `buildRunningBase` — nicht `maintainCurrent`. Radfahren erhält Ausdauer, ersetzt aber kein laufspezifisches Training.
- **Prio 6** (ursprünglich): Nach einer Trainingspause ist das Volumen bereits niedrig. `reduceLoadThisWeek` wäre eine Empfehlung, noch weniger zu machen — das ist kontraproduktiv. Korrekt: gradueller Wiederaufbau → `buildRunningBase`.
- **Prio 6a** (neu): Bei Rennen in ≤ 2 Wochen ist kein sinnvoller Laufbasis-Aufbau mehr möglich. Plötzliche Volumensteigerung kurz vor Wettkampf riskiert Überlastungsverletzungen. Die Gap ist erkannt (`.recentGapDetected`), aber die konservative Handlung ist `maintainCurrent` — keine automatische Planänderung, keine Tapering-Empfehlung, keine Aussage über Renntauglichkeit.

**Schwellenwert `weeksToRace <= 2`:** `weeksToRace` ist `Int?`, berechnet via `Calendar.dateComponents([.weekOfYear], from: now, to: raceDate).weekOfYear`. Rennen in 6 Tagen → 0 Wochen. Rennen in 13 Tagen → 1 Woche. Rennen in 14 Tagen → 2 Wochen. Der Schwellenwert ≤ 2 Wochen entspricht ≤ 14 Tage, was die Mindestzeit für eine sichere Rückkehr zu regelmäßigem Lauftraining unterschreitet.

**Lokalisierung `integratedCoach.action.maintainCurrent`:** Wird zu "Aktuelles Programm beibehalten." geändert (statt "Du bist auf Kurs – weiter so." — letzteres ist irreführend bei Prio 6a, da die Gap erkannt wurde). Der kombinierte Text für Prio 6a wäre: "Trainingspause erkannt." + "Aktuelles Programm beibehalten." — ehrlich und ohne falsche Versprechen.

---

**Korrektur Problem A — Unvollständige Kalenderwochen und Gap-Streak:**

`CardioVolumeOverTimeAggregator.aggregate()` erzeugt IMMER einen Bucket für die aktuelle laufende Woche (loop-Invariante: `while cursor <= upper`, `upper = weekStartFor(now)`). Das letzte Element in `weeklySeries` ist IMMER die aktuelle, noch nicht abgeschlossene Woche.

**Fachliche Regel:** Für die Gap-Streak (`trailingGenuineGapStreak`) zählen ausschließlich **abgeschlossene** Kalenderwochen. Die aktuelle laufende Woche darf nie als zweite abgeschlossene Gap-Woche zählen.

**WP-A-Implementierungsanforderung:** `RaceProgressAssessment.Input` erhält ein neues Feld:
```swift
/// true, wenn die letzte Woche in `weeklySeries` die aktuelle, noch nicht
/// abgeschlossene Kalenderwoche ist. Immer `true` wenn Daten aus
/// `CardioVolumeOverTimeAggregator.aggregate()` stammen.
public let isCurrentWeekIncomplete: Bool
```

In `RaceProgressAssessment.assess()` wird das letzte Flag vor `trailingGenuineGapStreak` bedingt ausgeschlossen:
```swift
let flagsForStreak: [WeeklyFlag?]
if input.isCurrentWeekIncomplete && flags.last == .genuineGap {
    // Aktuelle Woche leer, aber noch nicht abgeschlossen — nicht als Gap-Woche werten
    flagsForStreak = Array(flags.dropLast())
} else {
    // Entweder vollständig abgeschlossene Wochen, oder aktuelle Woche hat bereits Aktivität
    flagsForStreak = flags
}
let trailingGapStreak = trailingGenuineGapStreak(flagsForStreak)
```

Das `weeklyFlags`-Feld im `Assessment`-Output (für Display) bleibt unverändert — es enthält ALLE Wochen inkl. der aktuellen. Nur die Streak-Berechnung nutzt `flagsForStreak`.

**Caller `RaceProgressCardModel.make()`:**
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

**Verhalten nach Fix:**

| Situation | flags | flagsForStreak | streak |
|-----------|-------|----------------|--------|
| 1 abgeschl. Gap + aktuelle Woche leer | [..., .genuineGap, .genuineGap] | [..., .genuineGap] | 1 (korrekt) |
| 2 abgeschl. Gap-Wochen | [..., .genuineGap, .genuineGap, nil(aktWoche)] | [..., .genuineGap, .genuineGap, nil] | 0? |
| 2 abgeschl. Gap-Wochen, aktWoche leer | [..., .genuineGap, .genuineGap, .genuineGap] | [..., .genuineGap, .genuineGap] | 2 (korrekt) |
| 2 abgeschl. Gap, aktWoche mit Lauf | [..., .genuineGap, .genuineGap, nil] | unverändert | 0 (korrekt) |
| 1 abgeschl. Gap, aktWoche mit Lauf | [..., .genuineGap, nil] | unverändert | 0 (korrekt) |

> ⚠️ Zeile 2 oben: Bei 2 abgeschlossenen Gap-Wochen und aktiver (nicht-leerer) aktueller Woche ist `flags.last != .genuineGap`, daher keine Ausschluss-Logik — streak = 0 (korrekt, da user diese Woche trainiert hat). Streaks werden von hinten gezählt: die erste nicht-`.genuineGap`-Flag bricht den Streak.

**`minimumConsecutiveGapWeeksForConcern = 2` bleibt:** Zwei abgeschlossene Gap-Wochen lösen Prio 6 aus — das bleibt unverändert. Die Korrektur verhindert nur, dass eine leere aktuelle Woche fälschlich als zweite abgeschlossene Gap-Woche zählt.

---

## 11. Kritisches Architektur-Review (10 Punkte)

| Punkt | Ergebnis |
|-------|---------|
| 1. Prioritätsregeln fachlich begründet? | Ja — nach Korrektur Prio 3 + 6 (s. §10) |
| 2. Kurzfristige Last überschreibt langfristigen Fortschritt fälschlich? | Nein — `.goalLikelyUnrealistic` (Prio 5) > `.loadIncreasedTooFast` (Prio 8) > `.onTrack` (Prio 11); Reihenfolge fachlich korrekt |
| 3. `insufficientData` vs `planAdjustmentAvailable` korrekt getrennt? | Ja — Prio 1 vs Prio 4; keine Überschneidung |
| 4. Fehlende RPE / Dauer? | Ja korrekt — `durationDataUnavailable` = informativer `DataQualityIssue`, blockiert keine Empfehlung |
| 5. Historische Läufe vor Coaching-Aktivierung berücksichtigt? | Ja — `windowStart` = früheste Session (nicht `cardioCoachingEnabledAt`); `minimumCompleteWeeksForTrend = 3` greift als Safety-Net |
| 6. Kraft / Cross-Training korrekt klassifiziert? | Ja — `isCrossTrainingOnly`, `combineLoadDevelopment` nach Korrektur Prio 3 |
| 7. Zieländerung HM→Marathon vollständig? | Ja — `planRequiringAdjustment()` → `CoachAdjustmentCardModel.make()` → `planAdjustmentPending = true` → Prio 4 |
| 8. Bestehende Plan-Mechanismen wiederverwendet? | Ja — `CoachAdjustmentCardModel.accept()` und `CardioFeasibilityCardModel.accept()` unverändert |
| 9. Doppelte Empfehlungen möglich? | Nein — reine pure function, kein State, deterministisch |
| 10. Deterministisch und testbar? | Ja — kein `Date()` oder `UUID()` im Advisor; `weeksToRace` von außen übergeben |

---

## 12. Offene Fragen (nach Review)

Keine verbleibenden offenen Fragen — alle drei Entscheidungen (A, B, C) sind in §9 entschieden. §10 korrigiert die Prioritätstabelle.

---

*Phase 3 Schritt 1 (Audit) und Schritt 2 (Design Review, inkl. Architektur-Review) abgeschlossen. Implementierung (Schritt 3) erfordert explizite Freigabe.*
