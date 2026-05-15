#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// One persisted workout session.
///
/// A row is created at workout *start* with `isCompleted=false` and `durationMinutes=0` (F63).
/// The final "Save" on the Summary screen does an UPDATE that fills stats and flips
/// `isCompleted=true`. Rows with `isCompleted=false` are surfaced as crash-recovery
/// banners on the Home screen (F72).
@Model
public final class WorkoutSession {
    public var startTime: Date
    public var endTime: Date
    public var durationMinutes: Int
    public var exerciseCount: Int
    public var totalSets: Int
    public var totalVolumeKg: Double
    public var notes: String?
    public var isCompleted: Bool

    /// True when this session is a "Ruhetag uebersprungen"-marker rather than
    /// a real workout. The session lives in the store with `isCompleted=true`
    /// so the `PlanNavigator` advances its pointer past the rest-day, but the
    /// History/Dashboard/Trophy-Room surfaces filter these out so the user
    /// never sees empty "phantom" sessions. Persists as an explicit flag
    /// (default false) so a missed-write doesn't accidentally hide real
    /// sessions.
    public var isRestDay: Bool = false

    /// Snapshotted day name at session start — keeps history readable even after
    /// the source `TrainingDay` is renamed or deleted (F123 Bug #2).
    public var dayName: String?

    /// DEL-057: Vom User auf der Finish-Half-Sheet gewaehltes Session-Gefuehl.
    /// 1 = Grossartig, 2 = Gut, 3 = Okay, 4 = Sehr schwer, 5 = Zerstoert.
    /// Wird vom `ProgressionApplicator` ausgewertet: bei 4/5 wird jede
    /// `.increaseWeight`-Action zwingend auf `.hold` ueberschrieben
    /// (Erschoepfungs-Veto). Optional, weil bestehende Sessions vor DEL-057
    /// kein Gefuehl tragen und auch nicht muessen.
    public var sessionFeeling: Int?

    /// DEL-084: Auf welchem Gear (Schuh / Bike) wurde diese Session
    /// gemacht? `.nullify` damit ein geloeschtes Gear die Session-Historie
    /// nicht mit sich reisst. Nil bei reinen Strength-Sessions oder wenn
    /// der User kein Gear gepflegt hat.
    @Relationship(deleteRule: .nullify)
    public var gear: Gear?

    @Relationship(deleteRule: .nullify)
    public var day: TrainingDay?

    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.session)
    public var logs: [ExerciseLog] = []

    public init(
        startTime: Date = Date(),
        endTime: Date = Date(),
        durationMinutes: Int = 0,
        exerciseCount: Int = 0,
        totalSets: Int = 0,
        totalVolumeKg: Double = 0.0,
        notes: String? = nil,
        isCompleted: Bool = false,
        isRestDay: Bool = false,
        dayName: String? = nil,
        day: TrainingDay? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.exerciseCount = exerciseCount
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
        self.notes = notes
        self.isCompleted = isCompleted
        self.isRestDay = isRestDay
        self.dayName = dayName
        self.day = day
    }

    /// True when this is a finished, non-rest-day session — i.e., a real
    /// trainings-session that should be visible in History/Trophy-Room and
    /// counted in PR-Detection and analytics. Use this everywhere instead of
    /// `isCompleted` alone, otherwise rest-day-marker rows leak into UI.
    public var isRealWorkout: Bool {
        isCompleted && !isRestDay
    }

    /// DEL-081: Drei-State-Kategorisierung der Session aus den geloggten
    /// Saetzen. UI-Surfaces (HistorySessionRow, WorkoutSummary, ActiveWorkout-
    /// Header) lesen das hier und schalten ihre Stats-Zeile entsprechend.
    /// DEL-093: Cardio-Detection beruecksichtigt auch `durationSeconds` —
    /// ein Ad-Hoc-Laufband ohne km-Eingabe gilt jetzt korrekt als Cardio.
    public var sessionCategory: SessionCategory {
        SessionCategory.evaluate(logs: logs.map {
            (isCardio: $0.resolvedIsCardio,
             distanceKm: $0.distanceKm,
             durationSeconds: $0.durationSeconds)
        })
    }

    /// DEL-081 Convenience — Summe `log.distanceKm` ueber alle Logs der
    /// Session. Strength-Logs tragen nil → 0 bei.
    public var totalDistanceKm: Double {
        logs.compactMap(\.distanceKm).reduce(0.0, +)
    }

    /// DEL-081 Convenience — Summe `log.durationSeconds` ueber alle Cardio-
    /// Logs. Wird fuer Average-Pace genutzt.
    public var totalCardioDurationSeconds: Int {
        logs.filter { $0.resolvedIsCardio }
            .compactMap(\.durationSeconds)
            .reduce(0, +)
    }
}
#endif
