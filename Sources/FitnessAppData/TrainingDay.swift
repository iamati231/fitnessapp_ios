#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

@Model
public final class TrainingDay {
    public var name: String
    public var weekday: Int
    public var type: DayType
    public var nextIntensity: DayIntensity

    public var plan: TrainingPlan?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.day)
    public var exercises: [Exercise] = []

    // MARK: - DEL-049 Archive-aware accessors

    /// User-facing exercise list: nur Uebungen, die der User aktiv sehen und
    /// trainieren soll. Filtert archivierte Eintraege (Urlaubs-Modus-Snapshots)
    /// aus, ohne sie zu loeschen. ALLE Views, die die "echte" Uebungs-Liste
    /// rendern (DayEditor, ActiveWorkout, Dashboard, PlanEditor-DayRow),
    /// muessen DIESE Property statt `exercises` lesen — sonst doppeln sich
    /// nach einem Equipment-Swap die Eintraege.
    public var activeExercises: [Exercise] {
        exercises.filter { !$0.isArchived }
    }

    /// Inverse — alle archivierten Snapshots. Wird vom
    /// `PlanEnvironmentMigrator.restoreOriginals` durchsucht: jeder archivierte
    /// Eintrag, dessen Equipment im neuen Env wieder passt, wird reaktiviert.
    public var archivedExercises: [Exercise] {
        exercises.filter { $0.isArchived }
    }

    public init(
        name: String,
        weekday: Int,
        type: DayType = .custom,
        nextIntensity: DayIntensity = .normal,
        plan: TrainingPlan? = nil
    ) {
        self.name = name
        self.weekday = weekday
        self.type = type
        self.nextIntensity = nextIntensity
        self.plan = plan
    }
}

// MARK: - Core protocol conformances

/// Lets `PlanNavigator.sortByWeekdayMondayFirst` sort `[TrainingDay]` directly
/// without the view layer projecting weekdays into a separate value array.
extension TrainingDay: WeekdayProvider {}
#endif
