import Foundation

/// Pure-data view of a single attempted set, decoupled from `ExerciseLog`
/// (SwiftData @Model). The view layer projects logs into this type before
/// passing them to `PRDetector`, keeping the algorithm Core-pure and testable
/// on every platform.
public struct LiftAttempt: Sendable, Hashable {
    public let exerciseName: String
    /// Stabile `ExerciseTemplate.id`-Referenz, falls aufloesbar (Settings-Epic
    /// Phase 6, EXLIB-07/09). `nil` fuer Alt-Daten ohne Backfill-Treffer oder
    /// WOD-Zeitformat-Attempts ohne Uebungs-Bezug. `PRDetector` gruppiert
    /// bevorzugt hierueber, damit ein Umbenennen der Uebung die Verlaufs-
    /// Kontinuitaet (Bestleistungs-Erkennung) nicht mehr bricht — Name bleibt
    /// nur noch der Fallback fuer nicht-aufloesbare Alt-Eintraege.
    public let exerciseTemplateID: UUID?
    public let weightKg: Double
    public let reps: Int
    public let date: Date
    public let isCardio: Bool
    public let isTimeBased: Bool

    /// DEL-064: Cardio-Distanz in km. Nil bei Strength + TimeBased.
    public let distanceKm: Double?
    /// DEL-064: Cardio-Dauer in Sekunden. Nil bei Strength; bei TimeBased
    /// optional (kann gesetzt sein als Spiegel von `reps`).
    public let durationSeconds: Int?

    /// DEL-156: Cardio-Equipment des Versuchs. Bei Strength/Bodyweight/
    /// TimeBased immer `.none`. Fliesst in den PR-Gruppierungs-Key, sodass
    /// z.B. ein Laufband-Lauf und eine Fahrradfahrt getrennte PR-Reihen
    /// bilden.
    public let cardioEquipment: CardioEquipment

    public init(
        exerciseName: String,
        exerciseTemplateID: UUID? = nil,
        weightKg: Double,
        reps: Int,
        date: Date,
        isCardio: Bool = false,
        isTimeBased: Bool = false,
        distanceKm: Double? = nil,
        durationSeconds: Int? = nil,
        cardioEquipment: CardioEquipment = .none
    ) {
        self.exerciseName = exerciseName
        self.exerciseTemplateID = exerciseTemplateID
        self.weightKg = weightKg
        self.reps = reps
        self.date = date
        self.isCardio = isCardio
        self.isTimeBased = isTimeBased
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.cardioEquipment = cardioEquipment
    }

    /// Weight × reps. The standard "set volume" metric used by `WorkoutAnalytics.bestSet`,
    /// `PRDetector` (best-set kind), and downstream widget surfaces.
    public var volume: Double {
        weightKg * Double(reps)
    }

    /// DEL-064: Pace fuer Cardio-Attempts (min/km). Nil wenn keine Distanz
    /// ODER keine Dauer ODER Distanz <= 0.
    public var paceMinPerKm: Double? {
        guard let distanceKm, distanceKm > 0,
              let durationSeconds, durationSeconds > 0
        else { return nil }
        return Double(durationSeconds) / 60.0 / distanceKm
    }
}
