#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

@Model
public final class TrainingDay {
    /// System-Name (Template-Default, z.B. "Brust" / "Push A"). Intern fuer
    /// Template-Identifikation verwendet. Display geht ueber `displayName`.
    public var name: String

    /// DEL-125: User-Custom-Override. Nil = Display nutzt lokalisierten
    /// Template-Namen. Non-nil = User-getippter Name gewinnt.
    public var customName: String?

    public var weekday: Int
    public var type: DayType
    public var nextIntensity: DayIntensity

    public var plan: TrainingPlan?

    /// DEL-123: i18n-Lookup-Key fuer den Tag-Namen.
    /// Wird beim Plan-Adopt aus `DaySpec.localizationKey` propagiert.
    /// Optional — User-renamen-Tage + Legacy-Daten haben nil und fallen
    /// via `TrainingDay.displayName`-Extension auf rohes `name`-Feld
    /// zurueck. Lightweight-Migration kompatibel.
    public var localizationKey: String?

    /// Zeitformat dieses Tags (AMRAP/EMOM/Auf Zeit) — `nil` fuer normales
    /// Satz/Wiederholungs-Training (unveraenderter Bestandsfall). Additive,
    /// optionale Felder: bestehende Rows migrieren lightweight auf `nil`.
    public var timeFormat: WorkoutTimeFormat?
    /// AMRAP-Deckel bzw. EMOM-Gesamtdauer in Minuten. Siehe `DaySpec.timeCapMinutes`.
    public var timeCapMinutes: Int?

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
        customName: String? = nil,
        weekday: Int,
        type: DayType = .custom,
        nextIntensity: DayIntensity = .normal,
        plan: TrainingPlan? = nil,
        localizationKey: String? = nil,
        timeFormat: WorkoutTimeFormat? = nil,
        timeCapMinutes: Int? = nil
    ) {
        self.name = name
        self.customName = customName
        self.weekday = weekday
        self.type = type
        self.nextIntensity = nextIntensity
        self.plan = plan
        self.localizationKey = localizationKey
        self.timeFormat = timeFormat
        self.timeCapMinutes = timeCapMinutes
    }
}

// MARK: - Core protocol conformances

/// Lets `PlanNavigator.sortByWeekdayMondayFirst` sort `[TrainingDay]` directly
/// without the view layer projecting weekdays into a separate value array.
extension TrainingDay: WeekdayProvider {}
#endif
