# AI Running Coach — Phase 1: Implementierungsplan

**Status:** Entwurf, wartet auf Freigabe. Baut auf
`docs/superpowers/specs/2026-11-06-ai-running-coach-phase1-design.md`
(freigegeben) auf. Keine Implementierung vor Freigabe dieses Plans.

## 0. Architektur-Recherche-Ergänzung (wichtiger Fund)

Beim Verifizieren der exakten Signaturen für diesen Plan wurde eine
Datenlücke entdeckt, die im Design-Dokument noch nicht sichtbar war:

**`Exercise.enduranceSportKindRaw`/`enduranceSportKind: TrainingTypeKind?`
(`Sources/DeltiqData/Exercise.swift:132-137`) existiert NUR auf der
Plan-Übung `Exercise`, NICHT als Snapshot auf `ExerciseLog`.** `ExerciseLog`
snapshottet bereits `exerciseIsCardioSnapshot`/`exerciseCardioEquipmentSnapshot`
(`Sources/DeltiqData/ExerciseLog.swift:50-63`) genau deshalb, weil
`Exercise` nach Plan-Bearbeitung/-Löschung verschwinden kann
(`exercise: Exercise?`, `.nullify`-Regel, siehe Typ-Doku dort) — aber es
gibt **keinen** `exerciseEnduranceSportKindSnapshot`. Für jeden Lauf-Log,
dessen zugehörige `Exercise` später gelöscht/ersetzt wurde (z. B. durch
eine Coach-Plananpassung — ironischerweise genau der Mechanismus aus den
letzten Tickets), wäre die Sportart danach **dauerhaft nicht mehr
rekonstruierbar**, selbst wenn die Einheit beim Loggen eindeutig als Lauf
markiert war. Das würde "gesamte verfügbare Laufhistorie nutzen"
(Design-Dokument, Regel 1) über die Zeit stillschweigend aushöhlen — immer
mehr alte, eigentlich eindeutige Läufe würden nach einer Plananpassung zu
`.ambiguousActivityWeek`.

**Entscheidung für diesen Plan:** `ExerciseLog` bekommt ein additives
`exerciseEnduranceSportKindSnapshot: String? = nil` + `resolvedEnduranceSportKind:
TrainingTypeKind?`-Accessor, exakt nach demselben Muster wie
`exerciseIsCardioSnapshot`/`resolvedIsCardio` (Snapshot-first, NICHT
live-first wie bei `cardioEquipment` — die geloggte Sportart ist eine
unveränderliche Tatsache des damaligen Laufs, kein nachträglich vom Nutzer
korrigierbares Vorlieben-Feld). Siehe Abschnitt 2, Datei 1.

## 1. Dateien und Verantwortlichkeiten

| Datei | Modul | Verantwortlichkeit |
|---|---|---|
| `Sources/DeltiqData/ExerciseLog.swift` (Erweiterung) | DeltiqData | Neues Snapshot-Feld für die Lauf-Sportart (Abschnitt 0). |
| `Sources/DeltiqCore/Analytics/CardioVolumeOverTimePoint.swift` (neu) | DeltiqCore | Reiner Werttyp: ein Wochen-Datenpunkt (Umfang, Häufigkeit, Long-Run, Pace, Intensitätsmix-Zähler, Cross-Training-Umfang, Klassifikations-Zähler). |
| `Sources/DeltiqCore/Analytics/CardioVolumeOverTimeAggregator.swift` (neu) | DeltiqCore | Reine Funktion, Vorbild `VolumeOverTimeAggregator`: nimmt eine Liste bereits extrahierter Tupel entgegen, bucketet wochenweise, lückenlos. KEINE SwiftData-Abhängigkeit. |
| `Sources/DeltiqData/CardioHistoryExtractor.swift` (neu) | DeltiqData | SwiftData-Glue: liest `WorkoutSession`/`ExerciseLog` eines Nutzers und baut daraus die Tupel-Liste für `CardioVolumeOverTimeAggregator.aggregate(...)`. Einzige Stelle, die `enduranceSportKind`/Snapshot-Auflösung anwendet. |
| `Sources/DeltiqCore/Analytics/RaceProgressAssessment.swift` (neu) | DeltiqCore | Reiner Orchestrator, Vorbild `FourWeekReviewOrchestrator`: Wochenserie + Ziel/Renndatum/Coaching-Beobachtungsbeginn/aktuelles `CardioFeasibilityCalculator.Result` → `Outcome`/`Concern`/`DataGap`. KEIN Fliesstext, KEINE Mutation. |
| `Sources/DeltiqData/RaceProgressDueCalculator.swift` (neu) | DeltiqData | Fälligkeits-Zustand nach Vorbild `FourWeekReviewDueStatus`: wann ist die nächste Analyse fällig, Persistenz des letzten Analyse-Zeitpunkts, Anker-Etablierung ohne erfundenes Datum. |
| `Sources/DeltiqData/UserBodyProfile.swift` (Erweiterung) | DeltiqData | Drei neue Felder (Abschnitt 2) + eine Zeile in `setEnduranceModality` zum Stempeln von `cardioCoachingEnabledAt`. |
| `Sources/DeltiqUI/Cardio/RaceProgressCardModel.swift` (neu) | DeltiqUI | Verbindet Extractor + Aggregator + Orchestrator + Due-Calculator zu einem Dashboard-Karten-Modell, Vorbild `CoachAdjustmentCardModel`/`FourWeekReviewAssembler`. |
| `Sources/DeltiqUI/Cardio/RaceProgressDetailView.swift` (neu) | DeltiqUI | Detailansicht, Struktur-Vorbild `CardioCoachDetailView`: zeigt Wochen-Zahlen, Befunde, Datenlücken-Hinweise. |
| `Sources/DeltiqUI/DashboardView.swift` (Erweiterung) | DeltiqUI | Neue Karte im bestehenden Karten-Schema, gated auf `raceProgressDismissedFingerprint`. |

**Bewusst NICHT angefasst (Nicht-Ziel, siehe Design-Dokument):**
`RunCoachPlanAdjustment`, `CoachAdjustmentCardModel`, `CoachAdjustmentPreviewView`,
`PlanGeneratorInstantiator`, `ActivePlanResolver` — Phase 1 hat keinerlei
Schreibzugriff auf `TrainingPlan`/`TrainingDay`. Keine neue Datei in diesem
Plan importiert `SwiftData` mit Schreibabsicht auf diese Typen.

## 2. Modell-Felder, Migration, Defaults

### `ExerciseLog` (additiv, Lightweight Migration)

```swift
/// Snapshot von `Exercise.enduranceSportKind` zum Log-Zeitpunkt - analog
/// `exerciseCardioEquipmentSnapshot`. Snapshot-first (nicht live-first):
/// die gelaufene Sportart ist eine unveraenderliche Tatsache des damaligen
/// Laufs, kein nachtraeglich korrigierbares Praeferenz-Feld.
public var exerciseEnduranceSportKindSnapshot: String? = nil
```
In `init(...)`: `self.exerciseEnduranceSportKindSnapshot =
(exercise?.isCardio == true) ? exercise?.enduranceSportKindRaw : nil`
(identisches Muster zu `exerciseCardioEquipmentSnapshot`).

```swift
/// Sportart-Snapshot, snapshot-first. `nil` fuer Alt-Logs vor diesem Feld
/// UND fuer Logs, deren Exercise nie eine Sportart trug - beide Faelle
/// sind "unbekannt", nicht "kein Lauf".
public var resolvedEnduranceSportKind: TrainingTypeKind? {
    if let raw = exerciseEnduranceSportKindSnapshot { return TrainingTypeKind(rawValue: raw) }
    return exercise?.enduranceSportKind
}
```
Default `nil` für jeden Alt-Log → fällt automatisch in
`.ambiguousActivityWeek` (korrektes, nie geratenes Verhalten für
Bestandsdaten ohne Sportart-Information).

### `UserBodyProfile` (additiv)

```swift
/// Beginn des Coaching-Beobachtungszeitraums (siehe Design-Dokument,
/// Abschnitt "cardioCoachingEnabledAt"). Grenzt NUR Plateau-/Inaktivitaets-
/// /Konsistenz-WARNUNGEN ein, schneidet NIE die fuer Trend-/Fortschritts-
/// Metriken genutzte Laufhistorie ab. Nie rueckwirkend erfunden.
public var cardioCoachingEnabledAt: Date? = nil

public var raceProgressLastAnalyzedAt: Date? = nil
public var raceProgressDismissedFingerprint: String? = nil
```

**Migration/Default-Strategie (kein erfundenes Datum):**
- Lightweight Migration: alle drei Felder defaulten auf `nil` für jedes
  bestehende Profil (SwiftData-Standardverhalten für ein neues optionales
  Feld mit Default, keine eigene Migrations-Logik nötig).
- `setEnduranceModality(_:runCoachEnabled:)` (`UserBodyProfile.swift:292-311`)
  bekommt EINE neue Zeile im bestehenden `if cardioCoachingEnabled &&
  !wasEnabled { ... }`-Block: `if cardioCoachingEnabledAt == nil {
  cardioCoachingEnabledAt = Date() }` — exakt am bestehenden
  False→True-Übergangspunkt, kein neuer Aufrufer nötig. Für jede ZUKÜNFTIGE
  Aktivierung ist das Datum damit real und korrekt.
- **Bestandsnutzer, die den Coach schon vor diesem Feld aktiviert hatten**
  (`cardioCoachingEnabled == true`, `cardioCoachingEnabledAt == nil`, der
  obige Übergang feuert nie, weil `wasEnabled` schon `true` ist): analog zu
  `FourWeekReviewDueStatus.establishObservationAnchorIfNeeded`
  (`Sources/DeltiqData/FourWeekReviewDueStatus.swift:210-218`) bekommt
  `RaceProgressDueCalculator` (Abschnitt 4) eine eigene
  `establishObservationAnchorIfNeeded(for:in:now:)`, die GENAU EINMAL,
  beim ersten Aufruf dieser Phase-1-Logik für ein Profil mit
  `cardioCoachingEnabled == true && cardioCoachingEnabledAt == nil`, das
  Feld auf `now` setzt — "Beobachtung beginnt nachweislich jetzt" ist eine
  wahre Aussage, kein erfundenes historisches Datum. Aufruf aus einem
  `.task` beim Erscheinen der neuen Karte, NIE aus `body` (identische
  Regel wie beim Vorbild).

## 3. Exakte Signaturen und Datenfluss DeltiqData ↔ DeltiqCore

### `CardioVolumeOverTimePoint` (DeltiqCore, reiner Werttyp)

```swift
public struct CardioVolumeOverTimePoint: Identifiable, Equatable, Sendable {
    public let weekStart: Date
    /// Nur enduranceSportKind == .running. Nie Cross-Training/Unbekannt.
    public let runningDistanceKm: Double
    public let runningSessionCount: Int
    /// Laengste Einzeldistanz der Woche unter den Lauf-Einheiten, nil wenn keine.
    public let longestRunKm: Double?
    /// Durchschnittspace (min/km) ueber alle Lauf-Einheiten der Woche mit
    /// bekannter Distanz UND Dauer. nil, wenn keine Einheit beides hat.
    public let averagePaceMinutesPerKm: Double?
    /// Platzhalter fuer HF-Trend - IMMER nil in Phase 1 (keine Datenquelle,
    /// siehe Design-Dokument "bestaetigte Datenluecken"). Bewusst als
    /// eigenes Feld statt weggelassen, damit Phase 2 die Spalte nicht neu
    /// einfuehren muss und die UI schon heute "Daten nicht verfuegbar" zeigen kann.
    public let averageHeartRateBpm: Double?
    /// Bekannte Nicht-Lauf-Ausdauer (enduranceSportKind == .cycling).
    public let crossTrainingSessionCount: Int
    /// Cardio-Einheiten mit enduranceSportKind == nil - echte Mehrdeutigkeit.
    public let ambiguousCardioSessionCount: Int
    /// Krafttrainings-Haeufigkeit dieser Woche (fuer das Lauf/Kraft-
    /// Haeufigkeits-Verhaeltnis, Design-Dokument Punkt 3 der "geklaerten
    /// Entscheidungen").
    public let strengthSessionCount: Int
    public let id: Date { weekStart }
}
```

### `CardioVolumeOverTimeAggregator` (DeltiqCore, reine Funktion)

```swift
public enum CardioVolumeOverTimeAggregator {
    public struct LoggedSession: Sendable {
        public let date: Date
        /// nil = keine Cardio-Aktivitaet in dieser Session (reine Kraft-Session).
        public let runningDistanceKm: Double?
        public let runningDurationSeconds: Int?
        /// true nur wenn mindestens ein Cardio-Log der Session
        /// enduranceSportKind == .running hat.
        public let isRunning: Bool
        /// true nur wenn mindestens ein Cardio-Log .cycling (und KEIN .running).
        public let isCrossTrainingOnly: Bool
        /// true wenn Cardio-Logs vorhanden, aber Sportart unbekannt (und
        /// kein .running in derselben Session).
        public let hasAmbiguousCardio: Bool
        /// true wenn die Session mindestens einen Strength-Log traegt.
        public let hasStrengthActivity: Bool
    }

    public static func aggregate(
        sessions: [LoggedSession],
        windowStart: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CardioVolumeOverTimePoint]
}
```
Lückenlos wie `VolumeOverTimeAggregator` — jede Kalenderwoche im Fenster
bekommt einen Eintrag, auch mit lauter 0/nil-Werten (ehrliche Lücken-
Darstellung, identisches Prinzip).

### `CardioHistoryExtractor` (DeltiqData, SwiftData-Glue)

```swift
public enum CardioHistoryExtractor {
    /// Baut die reine Input-Liste fuer den Aggregator aus den tatsaechlichen
    /// WorkoutSessions eines Profils. Einzige Stelle, die
    /// `ExerciseLog.resolvedEnduranceSportKind`/`resolvedIsCardio` liest.
    public static func loggedSessions(
        from sessions: [WorkoutSession]
    ) -> [CardioVolumeOverTimeAggregator.LoggedSession]
}
```
Pro `WorkoutSession` (nur `isRealWorkout == true`, siehe
`WorkoutSession.swift:319-321`): Cardio-Logs nach
`resolvedEnduranceSportKind` in `.running`/`.cycling`/`nil` einsortieren;
`isRunning`/`isCrossTrainingOnly`/`hasAmbiguousCardio` nach der Regel
"Running hat Vorrang" (eine Session mit sowohl Lauf- als auch
Rad-Einheiten zählt als `isRunning`, Cross-Training wird dabei nicht
verworfen, sondern bleibt als zusätzlicher Kontext in `crossTrainingSessionCount`
erhalten — siehe Testfall 13 in Abschnitt 5). `runningDistanceKm`/
`runningDurationSeconds` = Summe über NUR die `.running`-Logs (nicht
`WorkoutSession.totalDistanceKm`, das über ALLE Cardio-Logs summiert).

### `RaceProgressAssessment` (DeltiqCore, reiner Orchestrator)

```swift
public enum RaceProgressAssessment {
    public struct Input: Sendable, Equatable {
        public let weeklySeries: [CardioVolumeOverTimePoint]
        public let goal: CardioGoal
        public let raceDate: Date?
        /// nil = Beobachtungsbeginn unbekannt (sollte durch die
        /// Anker-Etablierung in Abschnitt 2 praktisch nie vorkommen, aber
        /// die Funktion bleibt fuer diesen Fall sicher: siehe Decision 2 unten).
        public let coachingObservationStart: Date?
        /// Vom Aufrufer FRISCH aus `weeklySeries` berechnet (z.B. Mittel der
        /// letzten 2-3 Wochen mit runningDistanceKm > 0) - NIEMALS
        /// `profile.weeklyBaseVolumeKm` (siehe Design-Dokument Punkt 2 der
        /// "geklaerten Entscheidungen" + Abschnitt 6 "Schutz vor stale
        /// Werten" unten).
        public let currentWeeklyVolumeKm: Double?
        public let now: Date
    }

    public enum WeeklyFlag: Sendable, Equatable, Codable {
        case beforeCoachingObservationPeriod
        case strengthOnlyWeek
        case crossTrainingOnlyWeek
        case ambiguousActivityWeek
        case genuineGap
        // .insufficientHistory ist KEIN Wochen-Flag, sondern ein globaler
        // DataGap (siehe unten) - zu wenige Wochen ist keine Eigenschaft
        // einer einzelnen Woche.
    }

    public enum Concern: Sendable, Equatable, Codable {
        case loadIncreasedTooFast(percentOverLastNWeeks: Double, weeks: Int)
        case insufficientRecovery(consecutiveHighLoadWeeks: Int)
        case volumePlateau(weeks: Int)
        case goalLikelyUnrealistic(CardioFeasibilityCalculator.Result)
        case strengthRunningImbalance(runSessionsPerWeek: Double, strengthSessionsPerWeek: Double)
    }

    public enum DataGap: Sendable, Equatable, Codable {
        case insufficientHistory(weeksAvailable: Int, weeksNeeded: Int)
        case noHeartRateData
        case coachingObservationStartUnknown
        case ambiguousActivityPresent(weekCount: Int)
    }

    public enum Outcome: Sendable, Equatable, Codable {
        case onTrack
        case attentionNeeded([Concern])
        case offTrack([Concern])
    }

    public struct Assessment: Sendable, Equatable {
        public let outcome: Outcome
        public let dataGaps: [DataGap]
        /// Je Wochenpunkt der zugeordnete Flag, PARALLEL zu `weeklySeries`
        /// (gleicher Index) - fuer die Detailansicht, NIE fuer die
        /// Plateau-/Inaktivitaets-Einstufung einer VOR-Coaching-Woche
        /// verwendet (siehe `WeeklyFlag`-Doku).
        public let weeklyFlags: [WeeklyFlag]
    }

    public static func assess(_ input: Input) -> Assessment
}
```

**Decision 1 (Konsistenz mit Design-Dokument):** `weeklyFlags[i]` wird
IMMER anhand `weeklySeries[i]` berechnet — unabhängig vom Flag fliesst der
reine Zahlenwert dieser Woche weiterhin in Umfangs-/Long-Run-/Pace-Trend
ein (Design-Dokument Regel 1: volle Historie für Trend-Metriken). Nur die
Ableitung VON `Concern.volumePlateau`/zukünftigen Inaktivitäts-Concerns
überspringt Wochen mit Flag != `.genuineGap` nach `.beforeCoachingObservationPeriod`-Filterung.

**Decision 2 (Umgang mit `coachingObservationStart == nil`):** Kommt
praktisch nur vor, wenn die Migrations-Etablierung aus Abschnitt 2 noch
nicht gelaufen ist (z. B. ein Test ruft `assess` direkt ohne vorherige
Anker-Etablierung auf). In diesem Fall wird JEDE Woche konservativ als
`.beforeCoachingObservationPeriod` behandelt (keine Plateau-/Inaktivitäts-
Warnung möglich) UND `DataGap.coachingObservationStartUnknown` wird
gesetzt — nie eine Warnung ausgeben, wenn der Beobachtungsbeginn selbst
unbekannt ist.

### `RaceProgressDueCalculator` (DeltiqData, Vorbild `FourWeekReviewDueStatus`)

```swift
@MainActor
public enum RaceProgressDueCalculator {
    public enum DueReason: Sendable, Equatable {
        case newCompletedRun
        case goalChanged
        case raceDateChanged
        case significantVolumeChange
        case periodicInterval
    }

    public enum State: Sendable, Equatable {
        case due(reasons: [DueReason])
        case notYetDue(nextCheckAt: Date)
    }

    /// Reiner Lesezugriff, sicher aus `body` aufrufbar - etabliert NICHTS.
    public static func state(
        for profile: UserBodyProfile,
        latestRunDate: Date?,
        currentWeeklyVolumeKm: Double?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> State

    /// Mutierender Teil (Anker-Etablierung, Abschnitt 2) - NIE aus `body`.
    public static func establishObservationAnchorIfNeeded(
        for profile: UserBodyProfile, now: Date = Date(), in context: ModelContext
    )

    /// Nach einer durchgefuehrten Analyse aufzurufen - setzt
    /// `raceProgressLastAnalyzedAt`. KEINE weitere Mutation (keine
    /// Fingerprint-Logik hier - das macht `RaceProgressCardModel.dismiss`,
    /// analog `CoachAdjustmentCardModel.dismiss`).
    @discardableResult
    public static func recordAnalysisCompleted(
        for profile: UserBodyProfile, now: Date = Date(), in context: ModelContext
    ) -> Bool
}
```
`periodicInterval`: 14 Tage seit `raceProgressLastAnalyzedAt` (Produktregel,
analog zur dokumentiert-willkürlichen 28/42-Tage-Regel von
`FourWeekReviewDueCalculator` — kein wissenschaftlicher Wert, im
Implementierungsplan änderbar). `significantVolumeChange`: > 20%
Abweichung zwischen den letzten beiden vollständigen Wochen (reuses die
gleiche Grössenordnung wie `CardioFeasibilityCalculator.maxWeeklyRampPercent`,
nur als Trigger-Schwelle, nicht als Bewertungs-Schwelle selbst — die
Bewertung bleibt `RaceProgressAssessment`s Aufgabe).

### Datenfluss (Gesamtbild)

```
WorkoutSession/ExerciseLog (DeltiqData, SwiftData)
    → CardioHistoryExtractor.loggedSessions(from:)                    [DeltiqData]
    → CardioVolumeOverTimeAggregator.aggregate(sessions:...)          [DeltiqCore, reine Fkt.]
    → RaceProgressAssessment.Input { weeklySeries, ..., currentWeeklyVolumeKm }
    → RaceProgressAssessment.assess(_:)                               [DeltiqCore, reine Fkt.]
    → RaceProgressCardModel (DeltiqUI) rendert Assessment + ruft
      RaceProgressDueCalculator.recordAnalysisCompleted nach Anzeige
```
`DeltiqCore` importiert in keiner dieser neuen Dateien `SwiftData` — exakt
dieselbe Zwei-Schichten-Trennung wie bei jedem bestehenden
Analytics-Baustein.

## 4. Schutz vor veralteten Wochenumfangs-Werten

`RaceProgressAssessment.Input.currentWeeklyVolumeKm` wird AUSSCHLIESSLICH
vom `RaceProgressCardModel` aus der frisch berechneten `weeklySeries`
abgeleitet (z. B. Mittel der letzten 2 vollständigen Wochen mit
`runningDistanceKm > 0`, exakte Fensterbreite im Implementierungsplan-Test
festgelegt) — `profile.weeklyBaseVolumeKm` wird in KEINER neuen Datei
dieses Plans gelesen. Ein dedizierter Test (`testNeverReadsStaleOnboardingWeeklyVolume`,
Abschnitt 5, Fall 15) prüft das per Quelltext-Grep auf
`RaceProgressCardModel.swift` UND `RaceProgressAssessment.swift` — dieselbe
Technik wie `CardioFeasibilityChoiceTests.swift:110` in diesem Repo bereits
für eine ähnliche Garantie nutzt.

## 5. Schutz vor ungewollter Planänderung

Phase 1 hat schlicht keinen Schreibpfad: keine der neuen Dateien importiert
`PlanGeneratorInstantiator`, mutiert `TrainingDay`/`TrainingPlan` oder ruft
`CoachAdjustmentCardModel.accept`/`RunCoachPlanAdjustment`-Funktionen auf.
Ein dedizierter Test (`testPhase1NeverImportsPlanMutationAPIs`, Fall 15)
prüft per Quelltext-Grep über alle 7 neuen Dateien, dass keine der
verbotenen Funktions-/Typnamen (`PlanGeneratorInstantiator`,
`applyCoachCardioAdjustment`, `insertCoachCardioDays`, `TrainingDay(`,
`context.insert`, `context.delete`) vorkommt — eine strukturelle Garantie,
keine Verhaltens-Annahme.

## 6. Vollständige Testmatrix (15 Fälle)

Die 15 Ticket-Fälle, angepasst auf den tatsächlichen Phase-1-Umfang (keine
KI, keine Planänderung — Fälle 11-13 des Original-Tickets beschreiben
Phase-3-Verhalten und werden hier durch die STRENGERE, für Phase 1
zutreffende Garantie "es gibt überhaupt keinen Schreibpfad" ersetzt, siehe
Anmerkung je Fall).

| # | Ticket-Fall | Phase-1-Test | Ort |
|---|---|---|---|
| 1 | Neue Laufeinheit löst Aktualisierung aus | `testNewCompletedRunMarksAnalysisDue` | `RaceProgressDueCalculatorTests` |
| 2 | Mehrere neue Einheiten → keine doppelten Analysen | `testMultipleNewRunsOnSameDayDoNotDuplicateDueReasons` + `testRecordAnalysisCompletedIsIdempotentAgainstConcurrentDueChecks` | `RaceProgressDueCalculatorTests` |
| 3 | Trainingspause korrekt erkannt | `testGenuineGapAfterCoachingActivationIsFlagged` | `RaceProgressAssessmentTests` |
| 4 | Steigender Wochenumfang erkannt | `testLoadIncreaseOver20PercentOverThreeWeeksRaisesConcern` | `RaceProgressAssessmentTests` |
| 5 | Stagnierende Leistungsentwicklung erkannt | `testFlatVolumeAcrossMinimumWeeksRaisesPlateauConcern` | `RaceProgressAssessmentTests` |
| 6 | Unzureichende Daten → keine erfundenen Aussagen | `testFewerThanMinimumWeeksProducesInsufficientHistoryDataGapNotAConcern` | `RaceProgressAssessmentTests` |
| 7 | Fehlende HF-Daten verhindern nicht die übrige Analyse | `testMissingHeartRateDataGapDoesNotBlockVolumeOrPaceAssessment` | `RaceProgressAssessmentTests` |
| 8 | Halbmarathon → Marathon führt zur Neubewertung des bestehenden Plans | `testGoalChangeReassessesEntireHistoryAgainstNewGoalWithoutDiscardingIt` | `RaceProgressAssessmentTests` |
| 9 | Krafttraining bleibt bei Plananpassungen berücksichtigt | `testStrengthSessionCountFeedsLoadRecoveryButNeverRunningVolume` | `CardioVolumeOverTimeAggregatorTests` |
| 10 | Abgeschlossene Einheiten bleiben unverändert | `testExtractorAndAggregatorNeverMutateSourceModels` (reine Werttyp-Rückgabe, kein `context.save`) | `CardioHistoryExtractorTests` |
| 11 | *(Original: ungültige KI-Vorschläge abgelehnt — N/A, keine KI in Phase 1)* | `testPhase1NeverImportsPlanMutationAPIs` (stärkere Garantie: kein Vorschlag, der validiert werden müsste, existiert überhaupt) | Quelltext-Test, Abschnitt 5 |
| 12 | *(Original: abgelehnte Vorschläge ändern Plan nicht — N/A)* | gleicher Test wie #11 deckt dies strukturell ab | — |
| 13 | *(Original: bestätigte Vorschläge aktualisieren Planinstanz — N/A, kein Confirm-Flow in Phase 1)* | gleicher Test wie #11 | — |
| 14 | Offline-Betrieb funktioniert weiterhin | `testNoNewFileImportsNetworkingFrameworks` (Grep auf `URLSession`/`Network` in allen 7 neuen Dateien) | Quelltext-Test |
| 15 | App-Neustart erhält Analyseergebnisse und ausstehende Vorschläge | `testRaceProgressLastAnalyzedAtSurvivesRealStoreRestart` (echter `ModelContainer`-Neustart, Vorbild `CardioGoalEditorPersistenceTests.testSavedCardioGoalSurvivesARealStoreRestart`) | `UserBodyProfilePersistenceTests` (neu oder Erweiterung) |

**Zusätzliche Fälle aus diesem Planungsgespräch** (über die ursprünglichen
15 hinaus, explizit vom Nutzer verlangt):

| # | Fall | Test |
|---|---|---|
| 16 | Coaching-Aktivierungsgrenze: Wochen vor `cardioCoachingEnabledAt` lösen nie eine Inaktivitäts-Warnung aus, fliessen aber weiterhin in den Umfangs-Trend ein | `testWeeksBeforeCoachingActivationNeverProduceInactivityConcernButStillCountTowardVolumeTrend` |
| 17 | Reine Kraft-Woche ist kein Lauf-Gap | `testStrengthOnlyWeekIsFlaggedNotAsGenuineGap` |
| 18 | Bekannte Cross-Training-Woche (Radfahren) ist kein Lauf-Gap und kein DataGap | `testCyclingOnlyWeekIsCrossTrainingNotGapNotDataGap` |
| 19 | Unbekannte Cardio-Aktivität wird nie als Laufen angenommen | `testAmbiguousEnduranceSportKindNeverCountsAsRunningDistance` |
| 20 | Migration Bestandsnutzer: kein erfundenes Aktivierungsdatum | `testEstablishObservationAnchorNeverBackdatesForExistingCoachingUser` |
| 21 | `ExerciseLog`-Sportart-Snapshot überlebt Exercise-Löschung | `testResolvedEnduranceSportKindSurvivesExerciseDeletion` |
| 22 | Stale-Onboarding-Schutz (Abschnitt 4) | `testNeverReadsStaleOnboardingWeeklyVolume` |
| 23 | Session mit sowohl Lauf- als auch Rad-Logs zählt als Running, Cross-Training-Kontext bleibt sichtbar | `testMixedRunAndCyclingSessionCountsAsRunningWithCrossTrainingContextPreserved` |

Alle Tests in `DeltiqCoreTests` (reine Funktionen, lokal auf Windows
ausführbar) ausser den SwiftData-gebundenen (`CardioHistoryExtractorTests`,
`RaceProgressDueCalculatorTests`, `UserBodyProfilePersistenceTests`), die
wie der gesamte `DeltiqData`/`DeltiqUI`-Bestand auf diesem Windows-Host
NICHT kompilierbar sind (ZIPFoundation/CZlib-MSVC-Konflikt, dokumentiertes,
vorbestehendes Problem) — werden gegen CI verifiziert, lokal nur durch
sorgfältige manuelle Signatur-Prüfung abgesichert.

## 7. Nicht in diesem Plan (bleibt Implementierungsdetail oder spätere Phase)

- Exakte UI-Texte/Layout von Karte und Detailansicht.
- Exakte Zahlen für "wie viele Wochen Mittel für `currentWeeklyVolumeKm`"
  und "wie viele Wochen Minimum für ein Plateau" — werden beim Schreiben
  der Tests in Abschnitt 6 festgelegt und dort dokumentiert, nicht hier
  vorab geraten.
- `enduranceSportKindRaw`-Werte jenseits `.running`/`.cycling` (Schwimmen,
  Rudern, ...) — `TrainingTypeKind` kennt diese heute nicht, daher ausser
  Scope; sollte eine neue Sportart eingeführt werden, ist das eine
  Core-Erweiterung ausserhalb von Phase 1.
- Phase 2 (KI-Schnittstelle), Phase 3 (Planoptimierung/Confirm-Flow), Phase
  4 (Background Tasks/Dashboard-Feinschliff) — eigene Pläne nach Abschluss
  und Freigabe von Phase 1.
