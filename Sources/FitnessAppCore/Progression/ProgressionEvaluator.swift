import Foundation

/// DEL-052 + DEL-053: Smart Auto-Progression.
///
/// Pure value-type-Algorithmus, der nach Abschluss einer Workout-Session
/// auswertet, ob das Gewicht fuer DIESE Uebung im naechsten Workout steigen,
/// gleich bleiben oder sinken soll. "Double Progression" mit dynamischer
/// RIR-Toleranz fuer Compound- vs. Isolation-Lifts.
///
/// Der Evaluator wird vom UI-Layer (FitnessAppData/ProgressionApplicator)
/// gefuettert mit der `[ProgressionInputSet]`-Projektion aus den
/// `ExerciseLog`-Eintraegen einer einzelnen Uebung. Er trifft KEINE
/// SwiftData-Calls und ist daher 1:1 auf Windows-CI testbar.
public enum ProgressionEvaluator {

    /// Default-RIR-Schwellen pro Uebungs-Typ (DEL-053).
    ///
    /// **Compound** (Kniebeuge, Kreuzheben, Bankdruecken etc.): grosserer
    /// Sicherheits-Puffer. Progression triggert bereits, wenn der User die
    /// obere Rep-Grenze schafft und maximal 3 Reps in Reserve hatte
    /// (`lastSet.rir <= 3`). Verletzungs-Risiko mit hohen Lasten ist real;
    /// kein "bis-zum-Versagen-pruegeln" noetig.
    ///
    /// **Isolation** (Curls, Triceps-Extensions, Lateral-Raises): muss
    /// naeher ans Versagen. Progression nur bei `lastSet.rir <= 1`. Auf
    /// schweren Compounds wuerde der Muskel sonst nie genug Reiz kriegen.
    public static let defaultRIRForCompound: Float = 3
    public static let defaultRIRForIsolation: Float = 1

    /// Auswertung pro Uebung.
    ///
    /// - Parameter loggedSets: Tatsaechlich geloggte Saetze dieser Uebung in
    ///   der jetzt abgeschlossenen Session. Cardio- und Time-Based-Lifts
    ///   sollten gar nicht erst hier landen — das Filtern uebernimmt der
    ///   `ProgressionApplicator`.
    /// - Parameter targetRepsRange: `repsMin...repsMax` der Plan-Uebung.
    /// - Parameter isCompound: True wenn Compound-Lift (Bankdruecken,
    ///   Kniebeuge, Kreuzheben, etc.). Default-RIR-Schwelle steigt → Puffer.
    /// - Parameter incrementStep: `progressionStep` der Plan-Uebung (kg).
    /// - Parameter targetRIROverride: Wenn vom User in den Plan-Settings
    ///   gesetzt, ueberschreibt sie den compound/isolation-Default. Nil =
    ///   Auto je nach `isCompound`.
    public static func evaluate(
        loggedSets: [ProgressionInputSet],
        targetRepsRange: ClosedRange<Int>,
        isCompound: Bool,
        incrementStep: Double,
        targetRIROverride: Float? = nil
    ) -> ProgressionAction {
        // Ohne Daten kein Update — defensive Default, der User merkt's nicht.
        guard !loggedSets.isEmpty else { return .hold }

        // Sortier-stabile "letzter Satz"-Auswahl: per orderIndex aufsteigend.
        let ordered = loggedSets.sorted { $0.setIndex < $1.setIndex }
        guard let lastSet = ordered.last else { return .hold }

        let upper = targetRepsRange.upperBound
        let lower = targetRepsRange.lowerBound

        // 1) Hat der User in JEDEM Satz die obere Rep-Grenze geknackt?
        //    `>=` statt `==`, weil manche User auch +1/+2 schaffen wollen
        //    (z.B. AMRAP-Last-Set-Style).
        let allHitUpper = ordered.allSatisfy { $0.reps >= upper }

        // 2) Hat der User in irgendeinem Satz die untere Grenze verfehlt UND
        //    war dabei am Versagen (RIR == 0)? Dann Deload-Signal — das
        //    Gewicht ist zu schwer, naechstes Mal eine Stufe runter.
        let catastrophicFail = ordered.contains { $0.reps < lower && $0.rir <= 0 }

        // 3) DEL-053: Dynamische RIR-Schwelle. Compounds duerfen mit RIR 2
        //    aufsteigen (Sicherheits-Puffer), Isolation muss naeher ans
        //    Versagen (RIR 1). User-Override schlaegt beide.
        let requiredRIR = targetRIROverride
            ?? (isCompound ? defaultRIRForCompound : defaultRIRForIsolation)
        // `lastSet.rir <= requiredRIR` → User war intensiv genug. Bei RIR-
        // Override durch User koennte er auch RIR 3 fordern, dann reicht
        // RIR 3 vom geloggten Set.
        let intensityClean = lastSet.rir <= requiredRIR

        if allHitUpper && intensityClean {
            return .increaseWeight(by: incrementStep)
        } else if catastrophicFail {
            return .deload(by: incrementStep)
        } else {
            return .hold
        }
    }
}

/// Pure-value-type-Projektion eines geloggten Satzes fuer den
/// `ProgressionEvaluator`. Nicht zu verwechseln mit `LiftAttempt` (das ist
/// die PR-Detection-Projektion ohne RIR). Mappen wir aus ExerciseLog
/// inkl. RIR + setIndex separat.
public struct ProgressionInputSet: Sendable, Hashable {
    public let setIndex: Int
    public let reps: Int
    public let rir: Float

    public init(setIndex: Int, reps: Int, rir: Float) {
        self.setIndex = setIndex
        self.reps = reps
        self.rir = rir
    }
}

/// Result eines Evaluator-Laufs fuer eine einzelne Uebung.
public enum ProgressionAction: Equatable, Sendable {
    /// Ziel erreicht — naechstes Workout +`step` kg auf suggestedWeight.
    case increaseWeight(by: Double)
    /// Mittelfeld — User soll's naechstes Mal sauberer schaffen, kein
    /// Gewichts-Wechsel.
    case hold
    /// Katastrophen-Fall — Gewicht war zu schwer, untere Rep-Grenze nicht
    /// erreicht. Empfehle, naechstes Mal `step` kg weniger zu probieren.
    case deload(by: Double)

    /// Convenience fuer UI-Render — wie viel das Gewicht sich aendert (+/-).
    /// Hold → 0.
    public var weightDelta: Double {
        switch self {
        case .increaseWeight(let by): return by
        case .deload(let by):         return -by
        case .hold:                   return 0
        }
    }
}

/// DEL-052: erlaubte Inkrement-Stufen pro Uebung. UI-Picker mappt diese
/// auf das `progressionStep`-Double-Feld der Plan-Uebung.
public enum ProgressionStep: Double, CaseIterable, Sendable, Hashable {
    case quarter = 1.25   // Iso-Lifts mit Fractional-Plates
    case half    = 2.5    // Default fuer die meisten Uebungen
    case full    = 5.0    // Heavy Compounds (Kniebeuge / Kreuzheben)

    /// Best-fit Mapping zum eingespeicherten Double-Wert. Wenn der User
    /// per ExerciseEditor-Stepper eigene Werte eingibt (z.B. 1.0), kommt
    /// hier `.half` als sicherster Default — den User-Wert behaelt die
    /// Plan-Uebung selber, der enum dient nur dem Picker-UI.
    public init(closestTo raw: Double) {
        let allValues = Self.allCases
        let closest = allValues.min(by: { abs($0.rawValue - raw) < abs($1.rawValue - raw) })
        self = closest ?? .half
    }

    public var label: String {
        switch self {
        case .quarter: return "1,25 kg"
        case .half:    return "2,5 kg"
        case .full:    return "5 kg"
        }
    }
}
