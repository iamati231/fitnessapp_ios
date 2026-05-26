#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// DEL-142: Heuristischer Tages-Analyzer.
///
/// Nimmt eine Liste von `Exercise`-Models (typischerweise
/// `day.activeExercises`) und liefert ein `DayAnalysis`-Value-Bundle.
/// Pure-Berechnung ohne Side-Effects; ideal fuer Live-Updates im
/// SwiftUI-Layer (View-Compute auf jeden Render).
///
/// **Heuristik-Modell** (Ticket-Scope V1):
///   * Pro Satz → 1.0 Reizpunkte auf den Primärmuskel der Übung.
///     Compound-Lift bekommt zusätzlich `compoundBonusFactor = 1.15`,
///     weil ein Compound mehrere Muskeln gleichzeitig belastet.
///     Sekundärmuskel-Bonus kommt mit V2 wenn die Library
///     `secondaryMuscles`-Annotation hat.
///   * Pro Übung × Satz → Last-Score-Beitrag basierend auf den
///     DEL-098-Belastungsfaktoren (systemicFatigue + localMuscleDamage
///     + cnsDemand + technicalComplexity, gewichtet).
///   * Pro Übung Dauer = Sätze × (Arbeitszeit + Pause) + Wechselzeit.
///   * Recovery-Bucket = max-Stimulus-Muskel × Erholungs-Multiplikator
///     (siehe `recoveryRangeForTopStimulus`).
///
/// **Edge Cases:**
///   * Leere Übungs-Liste → `nil` (Caller rendert Empty-State).
///   * Cardio-only-Tag → CardioCoachNote + Duration-fokussiert,
///     Muskel-Focus wird auf core/quads/calves abstrahiert weil die
///     Library keine running-spezifischen Muskeln traegt.
///   * Custom-Übung ohne Library-Match → fließt in Last- + Dauer-
///     Score ein, aber kein Muscle-Focus-Beitrag (kein primaryMuscle
///     resolvable).
@MainActor
public enum DayAnalyzer {

    public static func analyze(
        exercises: [Exercise]
    ) -> DayAnalysis? {
        // Nur aktive Working-Sets fliessen in die Analyse — Warmup +
        // Cooldown werden vom User als optional erlebt und sollen die
        // Dauer/Belastung nicht aufblasen.
        let working = exercises.filter {
            !$0.isArchived && $0.role == .workingSet
        }
        guard !working.isEmpty else { return nil }

        let isCardioOnly = working.allSatisfy { $0.isCardio }

        // ── 1) Muscle-Focus ────────────────────────────────────────────
        let muscleFocus = computeMuscleFocus(working: working)

        // ── 2) Load-Score ──────────────────────────────────────────────
        let loadScore = computeLoadScore(working: working)
        let loadCategory = categorize(loadScore: loadScore)

        // ── 3) Systemic-Load (separate Achse) ──────────────────────────
        let systemicScore = computeSystemicScore(working: working)
        let systemicLoad = categorize(loadScore: systemicScore, scale: .systemic)

        // ── 4) Dauer-Range ─────────────────────────────────────────────
        let durationRange = computeDurationRange(working: working)

        // ── 5) Recovery-Range (lokal, Top-Muskel) ──────────────────────
        let recoveryRange = recoveryRangeForTopStimulus(
            muscleFocus: muscleFocus,
            isCardioOnly: isCardioOnly,
            systemicLoad: systemicLoad
        )

        // ── 6) Coach-Note ──────────────────────────────────────────────
        let coachNote = selectCoachNote(
            loadCategory: loadCategory,
            systemicLoad: systemicLoad,
            muscleFocus: muscleFocus,
            isCardioOnly: isCardioOnly
        )

        // ── 7) "Estimated"-Flag ────────────────────────────────────────
        // Wenn irgendeine Übung 0 Sätze oder repsMin=0 hat, kennzeichnen
        // wir die Analyse als grobe Schätzung.
        let isEstimated = working.contains { $0.sets <= 0 || $0.repsMin <= 0 }

        return DayAnalysis(
            loadScore: loadScore,
            loadCategory: loadCategory,
            muscleFocus: muscleFocus,
            estimatedDurationMinutes: durationRange,
            localRecoveryHours: recoveryRange,
            systemicLoad: systemicLoad,
            coachNote: coachNote,
            isEstimated: isEstimated
        )
    }

    // MARK: - Muscle Focus

    /// Aggregiert Primärmuskel-Stimulus über alle Übungen, sortiert
    /// nach Punktzahl absteigend, klassifiziert in 3 Tiers.
    private static func computeMuscleFocus(working: [Exercise]) -> [MuscleStimulus] {
        var perMuscle: [MuscleGroup: Double] = [:]

        for exercise in working {
            guard let primary = primaryMuscle(for: exercise) else { continue }
            // Ein Compound-Satz beruehrt mehr Muskelgewebe als Iso —
            // kleiner Bonus damit das visuell durchschlaegt.
            let compoundBonus = exercise.isCompound ? 1.15 : 1.0
            // Intensitaets-Faktor: niedrigerer Target-RIR (naeher am
            // Versagen) verursacht mehr lokalen Reiz.
            let intensityFactor = intensityMultiplier(targetRir: exercise.targetRir)
            let perSet = compoundBonus * intensityFactor
            let total = Double(exercise.sets) * perSet
            perMuscle[primary, default: 0] += total
        }
        guard let maxPoints = perMuscle.values.max(), maxPoints > 0 else {
            return []
        }
        // Tier-Bucketing relativ zum Maximum:
        //   >= 70% → primary, >= 30% → secondary, sonst tertiary.
        let sorted = perMuscle
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
        return sorted.map { (muscle, points) in
            let ratio = points / maxPoints
            let tier: MuscleStimulus.Tier
            if ratio >= 0.7      { tier = .primary }
            else if ratio >= 0.3 { tier = .secondary }
            else                 { tier = .tertiary }
            return MuscleStimulus(muscle: muscle, points: points, tier: tier)
        }
    }

    /// Library-Lookup für den Primärmuskel via `exercise.name`. Custom-
    /// Übungen ohne Library-Match liefern nil → Muscle-Focus erhält
    /// keinen Beitrag, die anderen Achsen (Load/Dauer) zaehlen sie aber
    /// normal mit. Cardio-Übungen → nil (kein klassischer Hypertrophie-
    /// Muskel, die Card hat einen Cardio-Fokus-Hint statt Heatmap).
    private static func primaryMuscle(for exercise: Exercise) -> MuscleGroup? {
        if exercise.isCardio { return nil }
        return ExerciseLibraryData.all
            .first(where: { $0.name == exercise.name })?
            .primaryMuscle
    }

    // MARK: - Load Score (Gesamtbelastung)

    /// Gewichtete Summe ueber alle Sätze. Setzt sich primaer aus den
    /// DEL-098-Faktoren zusammen (siehe `Exercise.systemicFatigueFactor`
    /// etc.). Range typischerweise 0...80; das Categorize-Mapping
    /// (siehe `categorize(loadScore:)`) kennt die Tages-Schwellen.
    private static func computeLoadScore(working: [Exercise]) -> Double {
        var score: Double = 0
        for ex in working {
            // Komposit-Faktor pro Satz aus den 4 Achsen.
            let perSet =
                ex.systemicFatigueFactor    * 0.30 +
                ex.localMuscleDamageFactor  * 0.30 +
                ex.cnsDemandFactor          * 0.20 +
                ex.technicalComplexityFactor * 0.10 +
                ex.axialLoadFactor           * 0.10
            let intensity = intensityMultiplier(targetRir: ex.targetRir)
            score += Double(ex.sets) * perSet * intensity * 10.0
        }
        return score
    }

    /// Separate System-Achse: berücksichtigt nur CNS- + systemicFatigue-
    /// Faktoren + axialLoad. Wird zur Recovery-Empfehlung herangezogen.
    ///
    /// **Iteration 2026-05-22**: Der naive ungedaempfte Score liess Tage
    /// mit vielen Isolationen (Curls, Face Pulls, Calf Raises) auf
    /// "Sehr hoch" hochpoppen, obwohl ZNS-Belastung dort minimal ist.
    /// Drei-Wege-Branch:
    ///   * Cardio: pauschaler Mini-Beitrag (0.5 pro Satz). Cardio
    ///     belastet das ZNS anders als schwere Compounds — Ausnahme
    ///     waeren HIIT-Intervalle, die hier aber nicht separat
    ///     klassifiziert sind.
    ///   * Compound-Lift: voller perSet × intensity-Score.
    ///   * Isolation: gleicher perSet, aber durch `0.15`-Dampener stark
    ///     gedrosselt. Curls + Maschinen belasten das ZNS kaum.
    ///
    /// Resultat: ein Tag mit 4 Compound-Saetzen liefert deutlich
    /// hoeheren systemicScore als ein Tag mit 12 Iso-Saetzen — was die
    /// Realitaet matched.
    private static func computeSystemicScore(working: [Exercise]) -> Double {
        var score: Double = 0
        for ex in working {
            if ex.isCardio {
                score += Double(ex.sets) * 0.5
                continue
            }
            let isolationDampener: Double = ex.isCompound ? 1.0 : 0.15
            let perSet =
                ex.systemicFatigueFactor * 0.45 +
                ex.cnsDemandFactor       * 0.35 +
                ex.axialLoadFactor       * 0.20
            let intensity = intensityMultiplier(targetRir: ex.targetRir)
            score += Double(ex.sets) * perSet * isolationDampener * intensity * 10.0
        }
        return score
    }

    /// Intensität → niedrigerer Target-RIR ist näher am Versagen, also
    /// mehr Last pro Satz. Skala: RIR 0 → 1.2, RIR 2 → 1.0 (Default),
    /// RIR 4 → 0.85, RIR 5+ → 0.75.
    private static func intensityMultiplier(targetRir: Float) -> Double {
        switch targetRir {
        case ...0.5:           return 1.20
        case 0.5...1.5:        return 1.10
        case 1.5...2.5:        return 1.00
        case 2.5...3.5:        return 0.90
        case 3.5...4.5:        return 0.85
        default:               return 0.75
        }
    }

    /// Bucketing-Schwellen: low < 12, moderate < 24, high < 40, sonst
    /// veryHigh. Werte sind aus Probe-Berechnungen abgeleitet (z.B.
    /// schwerer Leg-Day mit 4 Compounds × 4 Sätzen × RIR 2 ≈ 32-40).
    /// `scale: .systemic` verwendet engere Schwellen weil System-Score
    /// kleiner ausfaellt als Gesamt-Score.
    private static func categorize(loadScore: Double, scale: CategorizeScale = .total) -> LoadCategory {
        switch scale {
        case .total:
            switch loadScore {
            case ..<12:  return .low
            case ..<24:  return .moderate
            case ..<40:  return .high
            default:     return .veryHigh
            }
        case .systemic:
            switch loadScore {
            case ..<8:   return .low
            case ..<16:  return .moderate
            case ..<28:  return .high
            default:     return .veryHigh
            }
        }
    }

    private enum CategorizeScale { case total, systemic }

    // MARK: - Duration

    /// Untere/obere Schätzung basierend auf Sätzen × (Arbeitszeit +
    /// Pause) + Wechsel zwischen Übungen. Untere Grenze = effizienter
    /// User, obere = entspanntes Tempo mit echten Pausen.
    private static func computeDurationRange(working: [Exercise]) -> ClosedRange<Int> {
        var minSec: Int = 0
        var maxSec: Int = 0

        for ex in working {
            let perSetWork = workTimePerSet(exercise: ex)
            let restMin = max(ex.restSeconds - 15, 30)
            let restMax = ex.restSeconds + 15
            for _ in 0..<ex.sets {
                minSec += perSetWork.lower + restMin
                maxSec += perSetWork.upper + restMax
            }
            // Wechselzeit zur naechsten Übung
            minSec += 30
            maxSec += 60
        }
        // Last-rest wird nicht voll gezaehlt (User geht nach letztem
        // Satz direkt zur naechsten Übung statt zu rasten).
        let minMin = max(1, minSec / 60 - 1)
        let maxMin = max(minMin, maxSec / 60 + 1)
        return minMin...maxMin
    }

    /// Arbeitszeit pro Satz, range. Cardio nutzt targetDurationMinutes
    /// wenn gesetzt; sonst Default-Range basierend auf Typ.
    private static func workTimePerSet(exercise ex: Exercise) -> (lower: Int, upper: Int) {
        if ex.isCardio {
            // Cardio: Dauer ist die Übung selbst, nicht ein Satz × Pause.
            // Wir mappen targetDurationMinutes auf eine ungefähre Range.
            let mins = ex.targetDurationMinutes ?? 20
            let totalSec = mins * 60
            return (lower: totalSec, upper: totalSec + 60)
        }
        if ex.isTimeBased {
            // Time-Based (Plank, Wall-Sit): Sekunden = repsMin Range.
            let avgSec = max((ex.repsMin + ex.repsMax) / 2, 20)
            return (lower: max(avgSec - 5, 15), upper: avgSec + 5)
        }
        // Strength: 30-60 Sek pro Satz typisch (compound länger, iso kürzer).
        let baseLower = ex.isCompound ? 40 : 25
        let baseUpper = ex.isCompound ? 60 : 45
        return (lower: baseLower, upper: baseUpper)
    }

    // MARK: - Recovery

    /// Recovery-Range fuer den Top-Stimulus-Muskel. Mappt das Stimulus-
    /// Volumen auf eine Stunden-Range basierend auf der Heuristik aus
    /// dem Ticket (18-72h Buckets).
    ///
    /// Cardio-only-Tag bekommt eine separate Range (24-36h fuer typische
    /// easy/moderate-Cardio-Sessions).
    private static func recoveryRangeForTopStimulus(
        muscleFocus: [MuscleStimulus],
        isCardioOnly: Bool,
        systemicLoad: LoadCategory
    ) -> ClosedRange<Int> {
        if isCardioOnly {
            switch systemicLoad {
            case .low:      return 12...24
            case .moderate: return 18...30
            case .high:     return 24...36
            case .veryHigh: return 36...48
            }
        }
        let topPoints = muscleFocus.first?.points ?? 0
        // Top-Points-Buckets (kalibriert via Probe-Berechnung):
        //  <  6 Punkte → light       18-30h
        //  <  12       → moderate    24-48h
        //  <  20       → high        36-60h
        //  >= 20       → veryHigh    48-72h
        switch topPoints {
        case ..<6:   return 18...30
        case ..<12:  return 24...48
        case ..<20:  return 36...60
        default:     return 48...72
        }
    }

    // MARK: - Coach-Note Selection

    /// Wählt ONE Coach-Note basierend auf der Konstellation. Reihenfolge
    /// der Branches kodiert die Priorität — sehr-hohe Last und Cardio-
    /// only haben Vorrang vor generischen Templates.
    private static func selectCoachNote(
        loadCategory: LoadCategory,
        systemicLoad: LoadCategory,
        muscleFocus: [MuscleStimulus],
        isCardioOnly: Bool
    ) -> CoachNoteKind {
        if isCardioOnly { return .cardioFocused }
        if loadCategory == .veryHigh || systemicLoad == .veryHigh {
            return .veryHighStress
        }
        if loadCategory == .low { return .lightDeload }
        if systemicLoad == .high && loadCategory == .high {
            return .compoundHeavy
        }
        if loadCategory == .high && systemicLoad == .moderate {
            return .highLocal
        }
        return .balanced
    }
}
#endif
