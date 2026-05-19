#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

@Model
public final class TrainingPlan {
    /// System-Name (deutsche Template-Default). Wird intern als Template-
    /// Anker fuer Library/Migrator-Lookups verwendet. NICHT direkt anzeigen
    /// — der Display-Pfad geht ueber `TrainingPlan.displayName`-Extension,
    /// die `customName` zuerst checkt und sonst auf den catalog-Wert via
    /// `localizationKey` faellt.
    public var name: String

    /// DEL-125: User-Custom-Override des Anzeigenamens. Nil = User hat nicht
    /// umbenannt → Display zeigt den lokalisierten Template-Namen.
    /// Non-nil = User-Override gewinnt vor System+Locale.
    public var customName: String?

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
        customName: String? = nil,
        programType: String = "",
        descriptionText: String = "",
        weeks: Int = 12,
        isActive: Bool = false,
        targetEnvironment: EnvironmentType = .gym,
        isTemplate: Bool = false,
        localizationKey: String? = nil
    ) {
        self.name = name
        self.customName = customName
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
