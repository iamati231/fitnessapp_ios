// DEL-195: Warmup-Ramp-Rechner — klassisches Aufwärm-Schema für Barbell-
// Lifts. Aus einem Ziel-Arbeitsgewicht wird eine Rampe erzeugt:
//
//   Leere Stange ×10  →  ~55% ×5  →  ~75% ×3  →  (~90% ×1 bei schweren
//   Lifts)  →  Arbeitsgewicht
//
// Die Prozent-Stufen folgen der gängigen Praxis (Starting Strength /
// 5/3/1-Umfeld): absteigende Reps bei steigendem Gewicht, damit das ZNS
// aktiviert wird, ohne Ermüdung vor den Arbeitssätzen aufzubauen.
//
// Pure function in Core — UI-Layer (ExerciseCard) rendert das Ergebnis,
// gated über den bestehenden `pref_show_warmups`-Toggle (DEL-092).

import Foundation

/// Ein Schritt der Aufwärm-Rampe.
public struct WarmupStep: Equatable, Sendable {
    /// Gesamtgewicht in kg (inkl. Stange). Bei `isBarOnly` == Stangengewicht.
    public let weightKg: Double
    /// Empfohlene Wiederholungen für diesen Schritt.
    public let reps: Int
    /// True für den Leere-Stange-Schritt — UI rendert dann "Leere Stange"
    /// statt der kg-Zahl.
    public let isBarOnly: Bool

    public init(weightKg: Double, reps: Int, isBarOnly: Bool = false) {
        self.weightKg = weightKg
        self.reps = reps
        self.isBarOnly = isBarOnly
    }
}

public enum WarmupRampCalculator {

    /// Standard-Stangengewicht (kg). Mirrors PlateCalculator-Konvention.
    ///
    /// DEL-242: `public` ist PFLICHT, auch wenn kein externer Aufrufer
    /// existiert — die Konstante ist Default-Argument von `ramp(...)`, und
    /// Default-Argumente werden an der AUFRUFSTELLE eingesetzt. Auf `internal`
    /// reduziert bricht der Build von FitnessAppData/FitnessAppUI, nicht der
    /// von Core. Gleiches gilt fuer `heavySingleThresholdKg`.
    public static let defaultBarKg: Double = 20.0

    /// Prozent-Stufen mit zugehörigen Reps, aufsteigend. Der 90%-Schritt
    /// wird nur bei schweren Arbeitsgewichten (>= `heavySingleThresholdKg`)
    /// eingefügt — bei 60 kg Bankdrücken wäre ein 54-kg-Single sinnlos
    /// nah am Arbeitsgewicht.
    static let stages: [(fraction: Double, reps: Int)] = [
        (0.55, 5),
        (0.75, 3),
        (0.90, 1),
    ]

    /// Ab diesem Arbeitsgewicht bekommt die Rampe den 90%-Single.
    public static let heavySingleThresholdKg: Double = 100.0

    /// Erzeugt die Aufwärm-Rampe für ein Ziel-Arbeitsgewicht.
    ///
    /// Die Parameter-Namen sagen "Kg", die Rechnung ist aber einheiten-
    /// agnostisch — für lbs-Anzeige einfach lbs-Werte + lbs-Konventionen
    /// reinreichen (Bar 45, Increment 5, heavySingleThreshold 220).
    ///
    /// - Parameter workingWeightKg: Ziel-Arbeitsgewicht inkl. Stange.
    /// - Parameter barWeightKg: Stangengewicht (Default 20 kg).
    /// - Parameter roundingIncrementKg: Plate-Rundung (Default 2.5 kg —
    ///   kleinstes übliches Plate-Paar).
    /// - Parameter heavySingleThreshold: Ab diesem Arbeitsgewicht wird
    ///   der 90%-Single eingefügt (Default 100 kg / für lbs 220 reichen).
    /// - Returns: Schritte aufsteigend, OHNE den Arbeitssatz selbst.
    ///   Leeres Array, wenn das Arbeitsgewicht zu leicht für eine
    ///   sinnvolle Rampe ist (<= Stange + ein Increment).
    public static func ramp(
        workingWeightKg: Double,
        barWeightKg: Double = defaultBarKg,
        roundingIncrementKg: Double = 2.5,
        heavySingleThreshold: Double = heavySingleThresholdKg
    ) -> [WarmupStep] {
        // Unterhalb von Stange + einem Plate-Paar gibt es nichts zu rampen.
        guard workingWeightKg > barWeightKg + roundingIncrementKg else { return [] }

        var steps: [WarmupStep] = [
            WarmupStep(weightKg: barWeightKg, reps: 10, isBarOnly: true)
        ]

        for stage in stages {
            // 90%-Single nur bei schweren Lifts.
            if stage.fraction >= 0.90 && workingWeightKg < heavySingleThreshold {
                continue
            }
            let raw = workingWeightKg * stage.fraction
            let rounded = (raw / roundingIncrementKg).rounded() * roundingIncrementKg
            // Schritt muss echt zwischen Stange und Arbeitsgewicht liegen —
            // sonst dupliziert er den Bar-Schritt oder klebt am Arbeitssatz.
            guard rounded > barWeightKg,
                  rounded <= workingWeightKg - roundingIncrementKg else { continue }
            steps.append(WarmupStep(weightKg: rounded, reps: stage.reps))
        }
        return steps
    }
}
