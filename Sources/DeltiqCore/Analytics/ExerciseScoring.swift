import Foundation

/// DEL-099: Pure-Logic-Recovery-Scoring. Schmiert die statischen
/// `ExerciseRecoveryClass`-Faktoren (DEL-098) auf die tatsaechlich
/// geloggten Trainingsdaten (Sets, RIR, Weight, Reps, Dauer). Lebt im
/// Core, damit die Formeln auf Windows-/Linux-CI getestbar bleiben.
///
/// **Vertrag:**
///   * RIR 3 = Baseline (Multiplier 1.0). RIR 0 (Muskelversagen) = 1.45×,
///     RIR ≥ 5 = floor 0.5×. Exponentieller-leichter Anstieg in Richtung
///     Failure-Training — belohnt smartes Volumen, bestraft Junk-Sets.
///   * Gewicht skaliert log10 — 100 kg Bankdruecken zaehlt NICHT 10× wie
///     10 kg Seitheben (den Unterschied faengt der Basis-Faktor pro Uebung
///     ab). Bodyweight (weight == 0) bekommt Multiplier 1.0.
///   * Time-Based / Cardio: Score = Minuten × 10 × Basis-Faktor. Linear
///     mit Dauer, weil das die natuerliche Stresskurve eines Laufes ist.
///   * Recovery-Mapping (Punkte → Stunden) hat fixe Schwellen — vor v1
///     Beta-Test feinjustieren.
public enum ExerciseScoring {

    // MARK: - Per-Set-Multiplikatoren

    /// RIR-Multiplikator: RIR 3 → 1.0, RIR 0 → 1.45, RIR 6 → 0.55, harter
    /// Floor 0.5×. Lineare Interpolation, kein echtes Exponential — fuer
    /// die UI-Lesbarkeit eines abrechnungsbaren Modells genug.
    public static func rirMultiplier(rir: Float) -> Double {
        let raw = 1.0 + (3.0 - Double(rir)) * 0.15
        return max(0.5, raw)
    }

    /// Weight-Skalierung: log10(weight + 10). Bodyweight (0 kg) liefert
    /// 1.0 (statt log10(10) = 1.0 — gleich). Schwere Lifts skalieren
    /// trotzdem flach: 100 kg → ~2.04, 200 kg → ~2.32. Der Basis-Faktor
    /// der Uebung tut den Rest.
    public static func weightMultiplier(weightKg: Double) -> Double {
        guard weightKg > 0 else { return 1.0 }
        return log10(weightKg + 10.0)
    }

    /// Volumen-Sensitivity fuer lokale Muskelschaden-Berechnung. Reps
    /// erhoehen DOMS staerker als CNS-Last. Multiplier = 1.0 + reps × 0.02
    /// → 5 reps = 1.10, 10 reps = 1.20, 20 reps = 1.40.
    public static func repsMultiplier(reps: Int) -> Double {
        1.0 + Double(reps) * 0.02
    }

    // MARK: - Set-Level-Scores

    private static let baseSetLoad: Double = 10.0

    /// CNS-Belastung eines Strength-Sets. Gewicht-skaliert, RIR-multipliziert.
    public static func strengthCNSScore(
        weightKg: Double,
        rir: Float,
        cnsDemandFactor: Double
    ) -> Double {
        baseSetLoad
            * weightMultiplier(weightKg: weightKg)
            * rirMultiplier(rir: rir)
            * cnsDemandFactor
    }

    /// Lokale-Muscle-Damage eines Strength-Sets. Reps-sensibler als CNS,
    /// kein Gewichts-Skalierer (DOMS haengt mehr am Volumen als an der
    /// absoluten Last — der Basis-Faktor fangt den Lift-Charakter ab).
    public static func strengthMuscleDamageScore(
        reps: Int,
        rir: Float,
        localMuscleDamageFactor: Double
    ) -> Double {
        baseSetLoad
            * repsMultiplier(reps: reps)
            * rirMultiplier(rir: rir)
            * localMuscleDamageFactor
    }

    /// Time-Based / Cardio-Score eines Logs. `factor` ist je nach Aufrufer
    /// `cnsDemandFactor` oder `localMuscleDamageFactor` — Caller waehlt,
    /// welche Score-Dimension er gerade berechnet.
    public static func timeBasedScore(
        durationSeconds: Int,
        factor: Double
    ) -> Double {
        guard durationSeconds > 0 else { return 0.0 }
        let minutes = Double(durationSeconds) / 60.0
        return minutes * baseSetLoad * factor
    }

    // MARK: - Session-Level-Aggregation

    /// Mapping abstrakte Punktzahl → Erholungs-Stunden.
    /// Schwellen: <50 = 12h, <150 = 24h, <300 = 48h, sonst 72h.
    /// **Wichtig:** Caller uebergibt das MAXIMUM aus CNS- und Muscle-
    /// Damage-Score, nicht die Summe — ZNS + Muskel sind separate Pools,
    /// die langsamere Recovery-Pool dominiert.
    public static func estimatedRecoveryHours(maxLoad: Double) -> Int {
        switch maxLoad {
        case ..<50:   return 12   // Active Recovery / sehr leicht
        case ..<150:  return 24   // Normaler Trainingstag
        case ..<300:  return 48   // Harter Leg Day / langes Cardio
        default:      return 72   // Overreaching-Bereich
        }
    }
}
