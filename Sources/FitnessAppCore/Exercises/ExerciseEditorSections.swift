import Foundation

/// DEL-066: Pure-Logik fuer die Section-Sichtbarkeit im ExerciseEditorView.
/// In Core ausgelagert, damit wir die Conditional-Rendering-Regeln 1:1 auf
/// Windows-CI XCTest-abdecken koennen, ohne UI-Snapshot-Testing-Frameworks
/// (SnapshotTesting / ViewInspector) als neue Package-Dependency ziehen zu
/// muessen.
///
/// Single-Source-of-Truth: die `ExerciseEditorView` ruft denselben
/// `ExerciseEditorSections.evaluate(...)`, sodass UI + Tests garantiert
/// nicht auseinanderdriften.
public enum ExerciseEditorSections {

    /// Welche Sections sind fuer diese Uebungs-Konfiguration sichtbar?
    public struct Visibility: Equatable, Sendable {
        /// "Saetze & Wiederholungen" — Stepper fuer sets / repsMin / repsMax.
        public let setsAndReps: Bool
        /// Ziel-Distanz + Ziel-Dauer Stepper (Cardio-only).
        public let cardioTargets: Bool
        /// "Pause & Intensitaet" — Container fuer Pause-Stepper + RIR-Stepper.
        public let pauseAndIntensity: Bool
        /// RIR-Stepper innerhalb der Pause-Section (Strength-only).
        public let targetRIR: Bool
        /// "Vorgeschlagenes Gewicht" — kg-TextField.
        public let suggestedWeight: Bool
        /// "Smart-Progression" — Compound-/Step-/Toggle-Settings (Strength-only).
        public let smartProgression: Bool

        public init(
            setsAndReps: Bool,
            cardioTargets: Bool,
            pauseAndIntensity: Bool,
            targetRIR: Bool,
            suggestedWeight: Bool,
            smartProgression: Bool
        ) {
            self.setsAndReps = setsAndReps
            self.cardioTargets = cardioTargets
            self.pauseAndIntensity = pauseAndIntensity
            self.targetRIR = targetRIR
            self.suggestedWeight = suggestedWeight
            self.smartProgression = smartProgression
        }
    }

    /// Auswertung: aus den zwei Toggle-Flags ergibt sich pro Section ein
    /// boolean. Wenn `isCardio` UND `isTimeBased` beide true reinkommen
    /// (sollte UI-side via mutual-exclusion verhindert werden, DEL-062),
    /// gewinnt Cardio im Display-Pfad — das matched die SetRow-Switch-
    /// Reihenfolge (Cardio → TimeBased → Strength).
    public static func evaluate(isCardio: Bool, isTimeBased: Bool) -> Visibility {
        if isCardio {
            // Cardio: nur Cardio-Target-Section, Rest komplett aus.
            return Visibility(
                setsAndReps: false,
                cardioTargets: true,
                pauseAndIntensity: false,
                targetRIR: false,
                suggestedWeight: false,
                smartProgression: false
            )
        }
        if isTimeBased {
            // Zeit-basiert: Saetze (mit Sek.-Range), Pause-Stepper, KEIN RIR,
            // KEIN Gewicht, KEINE Progression — Plank progresst ueber Sekunden,
            // nicht ueber kg.
            return Visibility(
                setsAndReps: true,
                cardioTargets: false,
                pauseAndIntensity: true,
                targetRIR: false,
                suggestedWeight: false,
                smartProgression: false
            )
        }
        // Strength (Default): alles bis auf Cardio-Targets sichtbar.
        return Visibility(
            setsAndReps: true,
            cardioTargets: false,
            pauseAndIntensity: true,
            targetRIR: true,
            suggestedWeight: true,
            smartProgression: true
        )
    }
}
