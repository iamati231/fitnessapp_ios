import Foundation

/// DEL-142: Result-Wert der Tagesanalyse fuer den Day-Editor.
///
/// Reines Value-Type-Bundle ohne SwiftData-Bezug, damit das Modell
/// shareable bleibt zwischen Day-Editor, Dashboard-Vorschau und
/// (perspektivisch) Active-Workout-Preview. Der eigentliche Compute-
/// Pfad lebt in `FitnessAppData.DayAnalyzer`, weil er ueber @Model
/// `Exercise`-Instanzen iteriert.
///
/// **Felder** (siehe Ticket-Scope):
///   * `loadScore` — interner Roh-Score; primaer fuer relative
///     Vergleiche zwischen Tagen (heute vs. gestern), nicht als
///     User-facing Wert. Bucketing in `LoadCategory` ist die
///     UI-relevante Aggregation.
///   * `loadCategory` — semantische Einordnung low/moderate/high/
///     veryHigh, mit Farb- + Label-Mapping fuer die Visual-Skala.
///   * `muscleFocus` — geordnete Liste der gestimulierten Muskel-
///     Gruppen (primary tier zuerst, dann secondary).
///   * `estimatedDurationMinutes` — Range statt fixer Minute (siehe
///     Ticket: "ungefähre Schätzung").
///   * `localRecoveryHours` — Range fuer den primär-Muskel mit dem
///     hoechsten Reiz.
///   * `systemicLoad` — separate Kategorie fuer Nervensystem/CNS-
///     Belastung. Schwer Compound-Tag → high, reiner Iso-Pump-Tag →
///     moderate, Maschine-only → low.
///   * `coachNote` — Pre-baked Template-Key (siehe `CoachNoteKind`).
///     Caller resolved den Catalog-Key fuer die finale Rendering.
///   * `isEstimated` — true wenn Sätze/Reps unvollständig sind und
///     wir Defaults annehmen mussten. UI kennzeichnet das visuell
///     ("grobe Schätzung").
public struct DayAnalysis: Equatable, Sendable {
    public let loadScore: Double
    public let loadCategory: LoadCategory
    public let muscleFocus: [MuscleStimulus]
    public let estimatedDurationMinutes: ClosedRange<Int>
    public let localRecoveryHours: ClosedRange<Int>
    public let systemicLoad: LoadCategory
    public let coachNote: CoachNoteKind
    public let isEstimated: Bool

    public init(
        loadScore: Double,
        loadCategory: LoadCategory,
        muscleFocus: [MuscleStimulus],
        estimatedDurationMinutes: ClosedRange<Int>,
        localRecoveryHours: ClosedRange<Int>,
        systemicLoad: LoadCategory,
        coachNote: CoachNoteKind,
        isEstimated: Bool
    ) {
        self.loadScore = loadScore
        self.loadCategory = loadCategory
        self.muscleFocus = muscleFocus
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.localRecoveryHours = localRecoveryHours
        self.systemicLoad = systemicLoad
        self.coachNote = coachNote
        self.isEstimated = isEstimated
    }
}

/// 4-Stufen-Skala fuer Tages-Belastung. Identisches Schema fuer
/// `loadCategory` (Gesamt) und `systemicLoad` (System/CNS-Anteil).
public enum LoadCategory: String, Sendable, CaseIterable {
    case low, moderate, high, veryHigh

    /// xcstrings-Key fuer das User-facing Label.
    public var localizationKey: String {
        "day.analysis.load.\(rawValue)"
    }
}

/// Pro-Muskel-Stimulus-Eintrag fuer die Focus-Sektion.
///
/// `points` ist der summierte Reizwert ueber alle Übungen+Sätze, die
/// den `muscle` als Primär-Muskel haben (Ticket-Heuristik: 1.0 pro
/// Satz fuer Primaer, abgeschwächt fuer Sekundär — V1 zaehlt nur den
/// Primaer-Muskel, Sekundaer-Lookup kommt mit V2 wenn die Library
/// secondary-Annotation bekommt).
///
/// `tier` ist die Reihenfolge-Klasse innerhalb der Sortierung:
/// `.primary` = top 2 Muskelgruppen des Tages, `.secondary` = mid,
/// `.tertiary` = leichte Mit-Belastung (Reiz < 30% des Primary).
public struct MuscleStimulus: Equatable, Sendable, Identifiable {
    public let muscle: MuscleGroup
    public let points: Double
    public let tier: Tier

    public var id: String { muscle.rawValue }

    public enum Tier: String, Sendable {
        case primary, secondary, tertiary

        /// xcstrings-Key. Symmetrisch zu `LoadCategory.localizationKey`
        /// und `CoachNoteKind.localizationKey` — die UI nutzt das
        /// computed-property-Pattern, damit `LocalizedStringKey(_:)` den
        /// String-Init und NICHT den Interpolation-Init bekommt
        /// (siehe DEL-143-Bugfix-Notes / CONTRIBUTING.md zu
        /// LocalizedStringKey-Patterns).
        public var localizationKey: String {
            "day.analysis.muscleFocus.tier.\(rawValue)"
        }
    }

    public init(muscle: MuscleGroup, points: Double, tier: Tier) {
        self.muscle = muscle
        self.points = points
        self.tier = tier
    }
}

/// Pre-baked Coach-Note-Templates. Die Analyzer-Logik wählt EINEN
/// dieser Cases basierend auf der (loadCategory × focusType × systemic)-
/// Konstellation. Catalog-Keys leben unter `day.analysis.coachNote.*`.
///
/// Bewusst pre-baked statt NLP-generiert (siehe Ticket: "Keine NLP-Texte
/// oder frei generierte KI-Erklärungen"). Sechs Templates decken die
/// häufigsten Tages-Profile ab; Edge-Cases fallen auf `.balanced`
/// zurueck.
public enum CoachNoteKind: String, Sendable, CaseIterable {
    /// Solider, ausgewogener Tag (moderate Last, gemischter Fokus).
    case balanced
    /// Hohes Volumen aber moderate Systemlast (typisch Iso-Pump-Tag).
    case highLocal
    /// Schwerer Compound-Tag (System + lokal beide hoch).
    case compoundHeavy
    /// Sehr hohe Last (rot) — Empfehlung fuer Erholung danach.
    case veryHighStress
    /// Sehr geringer Reiz — passt fuer Deload, Technik oder Erhaltung.
    case lightDeload
    /// Cardio-only-Tag. Eigene Sprach-Logik (Dauer + Distanz statt
    /// Hypertrophie-Reiz).
    case cardioFocused

    public var localizationKey: String {
        "day.analysis.coachNote.\(rawValue)"
    }
}
