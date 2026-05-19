#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

@Model
public final class TrainingPlan {
    public var name: String
    public var programType: String
    public var descriptionText: String
    public var weeks: Int
    public var isActive: Bool
    /// Environment this plan is designed for — used to filter recommendations (F154).
    public var targetEnvironment: EnvironmentType

    /// True wenn der Plan via `ProgramInstantiator` aus einer kuratierten
    /// `ProgramTemplate` erzeugt wurde. Read-Only-Logik in Plan/Day/Exercise-
    /// Editoren prueft DIESEN Flag, NICHT `programType.isEmpty` — sonst
    /// sperrt sich die UI sobald der User in einem Custom-Plan einen
    /// Programm-Typ eintippt (DEL-013-Bug).
    public var isTemplate: Bool = false

    /// DEL-053: Globaler User-Override der RIR-Schwelle fuer
    /// Smart-Progression in DIESEM Plan. Nil = Default-Logik
    /// (`ProgressionEvaluator.defaultRIRForCompound/Isolation`). Non-nil =
    /// alle Uebungen progressen erst, wenn `lastSet.rir <= override`.
    /// Beispiel: `override = 2` zwingt sowohl Compounds als auch Isolation
    /// auf RIR<=2 — strenger Modus.
    public var progressionTargetRIROverride: Float?

    /// DEL-123: i18n-Lookup-Key fuer den Plan-Namen.
    /// Wird beim Plan-Adopt aus `ProgramTemplate.localizationKey` propagiert.
    /// Optional — Custom-Plaene und Legacy-Daten (vor DEL-123) tragen nil
    /// und fallen via `TrainingPlan.displayName`-Extension auf das rohe
    /// deutsche `name`-Feld zurueck. Lightweight-Migration: SwiftData
    /// addiert das Feld als nil auf existierende Rows ohne Schema-Bruch.
    public var localizationKey: String?

    @Relationship(deleteRule: .cascade, inverse: \TrainingDay.plan)
    public var days: [TrainingDay] = []

    public init(
        name: String = "",
        programType: String = "",
        descriptionText: String = "",
        weeks: Int = 12,
        isActive: Bool = false,
        targetEnvironment: EnvironmentType = .gym,
        isTemplate: Bool = false,
        localizationKey: String? = nil
    ) {
        self.name = name
        self.programType = programType
        self.descriptionText = descriptionText
        self.weeks = weeks
        self.isActive = isActive
        self.targetEnvironment = targetEnvironment
        self.isTemplate = isTemplate
        self.localizationKey = localizationKey
    }
}
#endif
