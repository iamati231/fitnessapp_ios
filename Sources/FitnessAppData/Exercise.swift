#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

@Model
public final class Exercise {
    public var name: String
    public var sets: Int
    public var repsMin: Int
    public var repsMax: Int
    public var restSeconds: Int
    public var notes: String?
    public var suggestedWeight: Double?
    public var orderIndex: Int
    public var targetRir: Float
    public var weightReducedNote: String?
    /// True for cardio finishers — UI shows duration/level instead of kg/reps (F153).
    public var isCardio: Bool
    /// True for isometric/time-based exercises (Plank, Wall Sit) — reps record seconds (F161).
    public var isTimeBased: Bool

    /// DEL-049: Urlaubs-Modus / Equipment-Wechsel Snapshot.
    /// True wenn diese Uebung NICHT mehr im aktiven Plan-Slot steht, sondern
    /// als Fallback aufgehoben wird, weil sie durch eine Alternative ersetzt
    /// wurde (z.B. Bankdruecken im Gym-Plan → Liegestuetze im BW-Modus).
    /// Views nutzen `TrainingDay.activeExercises` statt `day.exercises`, um
    /// archivierte Eintraege aus der UI auszublenden. Die ExerciseLog-
    /// Relationship bleibt erhalten — wir verlieren also KEINE Historie.
    public var isArchived: Bool = false

    /// DEL-049: Wenn diese Uebung als Ersatz fuer eine andere eingefuegt wurde
    /// (Top-Down-Migration), zeigt das Property auf das Original. Beim
    /// Rueckweg ("Urlaub zu Ende") liest der Migrator dieses Feld, hebt das
    /// Original wieder aktiv und entsorgt die Ersatz-Uebung — inklusive
    /// Restore des letzten bekannten Arbeitsgewichts via Original-Logs.
    public var swappedFromOriginal: Exercise?

    // MARK: - DEL-052/053 Smart Auto-Progression

    /// Toggle pro Uebung — schaltet die automatische Gewichts-Steigerung an.
    /// Default `true`, sodass neue Uebungen sofort von der Logik profitieren.
    /// User kann es per ExerciseEditor pro Uebung ausschalten (z.B. fuer
    /// Cardio-Finisher, die manuell kalibriert werden).
    public var smartProgressionEnabled: Bool = true

    /// Inkrement-Stufe in kg fuer "Ziel erreicht → naechstes Mal hoeher".
    /// Default 2.5 kg (klassischer Plate-Pair). User-UI bietet 1.25 / 2.5 /
    /// 5.0 als Quick-Picker, das Feld erlaubt aber prinzipiell beliebige
    /// Doubles (custom Fractional-Plate-Setups).
    public var progressionStep: Double = 2.5

    /// True fuer Compound-Lifts (Bankdruecken, Kniebeuge, Kreuzheben,
    /// Schulterdruecken, Rudern). Steuert die RIR-Schwelle im
    /// `ProgressionEvaluator` — Compounds duerfen mit groesserem Puffer
    /// progressen (RIR 3), Isolation muss naeher ans Versagen (RIR 1).
    /// Default `false`; wird beim Insert aus `ExerciseTemplate.isSystemCompound`
    /// geseedet (siehe `DayEditorView.addExercise(from:)`).
    public var isCompound: Bool = false

    // MARK: - DEL-058 Cardio-Targets

    /// DEL-058: Ziel-Distanz in km fuer Cardio-Uebungen (z.B. Easy Run 5 km).
    /// Nil bei Strength + Time-Based. Wird als Placeholder im CardioSetRow
    /// angezeigt; der User kann beliebig daneben loggen.
    public var targetDistanceKm: Double?

    /// DEL-058: Ziel-Dauer in Minuten — vor allem fuer Easy/Long-Runs ohne
    /// fixe Distanz ("30 Min Easy"). Nil bei Strength.
    public var targetDurationMinutes: Int?

    /// DEL-083: Superset-Gruppe. Uebungen mit der gleichen UUID werden im
    /// Workout abwechselnd ausgefuehrt (A1, B1, A2, B2 statt A1, A2, A3,
    /// B1, B2, B3). Plan-Editor setzt die UUID via Swipe-Action "Link"; nil
    /// = standalone-Uebung wie bisher.
    public var supersetId: UUID?

    public var day: TrainingDay?

    /// DEL-051: HEILIGE HISTORIE. Frueher `.cascade` — beim Loeschen einer
    /// Plan-Uebung (manuell oder via Day/Plan-Cascade) gingen die ExerciseLog-
    /// Eintraege gleich mit weg, was Bestleistungen vernichtet hat. Jetzt
    /// `.nullify`: die Logs verlieren nur ihren `exercise`-Backref-Pointer,
    /// behalten aber ihren Snapshot in `exerciseNameSnapshot` /
    /// `exerciseIsCardioSnapshot` / `exerciseIsTimeBasedSnapshot` und bleiben
    /// fuer PR-Detection, Trophy-Room, Compound-Trends und alle anderen
    /// Statistik-Surfaces voll auswertbar.
    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.exercise)
    public var logs: [ExerciseLog] = []

    public init(
        name: String,
        sets: Int = 3,
        repsMin: Int = 8,
        repsMax: Int = 12,
        restSeconds: Int = 90,
        notes: String? = nil,
        suggestedWeight: Double? = nil,
        orderIndex: Int = 0,
        targetRir: Float = 2.0,
        weightReducedNote: String? = nil,
        isCardio: Bool = false,
        isTimeBased: Bool = false,
        isArchived: Bool = false,
        swappedFromOriginal: Exercise? = nil,
        smartProgressionEnabled: Bool = true,
        progressionStep: Double = 2.5,
        isCompound: Bool = false,
        targetDistanceKm: Double? = nil,
        targetDurationMinutes: Int? = nil,
        supersetId: UUID? = nil,
        day: TrainingDay? = nil
    ) {
        self.name = name
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.restSeconds = restSeconds
        self.notes = notes
        self.suggestedWeight = suggestedWeight
        self.orderIndex = orderIndex
        self.targetRir = targetRir
        self.weightReducedNote = weightReducedNote
        self.isCardio = isCardio
        self.isTimeBased = isTimeBased
        self.isArchived = isArchived
        self.swappedFromOriginal = swappedFromOriginal
        self.smartProgressionEnabled = smartProgressionEnabled
        self.progressionStep = progressionStep
        self.isCompound = isCompound
        self.targetDistanceKm = targetDistanceKm
        self.targetDurationMinutes = targetDurationMinutes
        self.supersetId = supersetId
        self.day = day
    }
}
#endif
