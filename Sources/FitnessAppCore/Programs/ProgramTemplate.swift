import Foundation

/// Pure-data spec for a complete training program (e.g., Push-Pull-Legs, 5×5).
/// Materialized into a `TrainingPlan` + `TrainingDay`s + `Exercise`s by
/// `ProgramInstantiator` in `FitnessAppData`.
public struct ProgramTemplate: Sendable, Hashable, Identifiable {
    /// Stable string identifier — persisted on `TrainingPlan.programType` so we can
    /// detect "user's plan was originally a PPL template" later for re-recommendations.
    public let id: String
    public let name: String
    public let tagline: String
    public let descriptionText: String
    public let focus: String
    public let daysPerWeek: Int
    /// DEL-088: `days` enthaelt jetzt NUR Trainings-Tage, sortiert nach
    /// `sequenceIndex` (1...daysPerWeek). Rest-Tage werden beim Instanziieren
    /// vom `ProgramInstantiator` automatisch in die restlichen Wochentage
    /// gefuellt — der User waehlt seine Wochentage erst beim Adopt.
    public let days: [DaySpec]
    public let targetEnvironment: EnvironmentType
    /// SF Symbol name displayed as the program tile icon. Picked per program;
    /// can be replaced with a real custom-asset on the iOS side later.
    public let iconSystemName: String

    /// DEL-090: Quiz-Matchmaker-Tags. Mehrwertig, damit ein Plan auf mehrere
    /// Antwortkombinationen passen kann (z.B. PPL ist sowohl Hypertrophie als
    /// auch Kraft; Hybrid passt Beginner UND Intermediate).
    public let targetExperience: [ExperienceLevel]
    public let targetGoals: [GoalType]

    /// DEL-113: i18n-Lookup-Key fuer den Plan-Namen (Format
    /// `plan.template.<id>`). Optional — wenn gesetzt, rendert die UI den
    /// Plan-Namen aus dem Localizable.xcstrings statt aus dem hardcoded
    /// deutschen `name`. Der `ProgramInstantiator` propagiert weiterhin den
    /// deutschen `name` auf `TrainingPlan.name`, weil die Name-basierte
    /// Lookup-Logik (ExerciseLibraryData.alternatives, PlanEnvironmentMigrator)
    /// auf den deutschen Strings beruht.
    public let localizationKey: String?

    /// DEL-116: i18n-Lookup-Keys fuer die drei Plan-Metadaten-Felder.
    /// Namespace: `plan.template.<id>.tagline / .focus / .description`.
    /// Wenn nil/leer, faellt der DisplayName-Helper auf das jeweilige rohe
    /// DE-Feld (`tagline` / `focus` / `descriptionText`) zurueck — User-
    /// erstellte Custom-Templates sehen also ihren handgetippten Text.
    public let taglineKey: String?
    public let focusKey: String?
    public let descriptionKey: String?

    /// DEL-170: Optionale Equipment-spezifische Varianten des Templates.
    /// `nil` = einzige Variante ist `days` (Standard, Backward-Compat). Wenn
    /// gesetzt, wählt der `ProgramInstantiator` anhand der
    /// `UserBodyProfile.equipmentPreferences` die passende `EquipmentVariant`;
    /// fällt auf `days` zurück, wenn keine kompatibel ist.
    public let equipmentVariants: [EquipmentVariant]?

    public init(
        id: String,
        name: String,
        localizationKey: String? = nil,
        tagline: String,
        taglineKey: String? = nil,
        descriptionText: String,
        descriptionKey: String? = nil,
        focus: String,
        focusKey: String? = nil,
        daysPerWeek: Int,
        days: [DaySpec],
        targetEnvironment: EnvironmentType = .gym,
        iconSystemName: String = "figure.strengthtraining.traditional",
        targetExperience: [ExperienceLevel] = [.intermediate],
        targetGoals: [GoalType] = [.hypertrophy],
        equipmentVariants: [EquipmentVariant]? = nil
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.descriptionText = descriptionText
        self.focus = focus
        self.daysPerWeek = daysPerWeek
        self.days = days
        self.targetEnvironment = targetEnvironment
        self.iconSystemName = iconSystemName
        self.targetExperience = targetExperience
        self.targetGoals = targetGoals
        self.localizationKey = localizationKey
        self.taglineKey = taglineKey
        self.focusKey = focusKey
        self.descriptionKey = descriptionKey
        self.equipmentVariants = equipmentVariants
    }
}
