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

    /// README 2.20: JSON-codiertes `PlanGeneratorInput`, gesetzt wenn dieser
    /// Plan ueber den "Plan bauen"-Assistenten erzeugt wurde. Nil = manuell
    /// angelegter oder direkt aus einem `ProgramTemplate` instanziierter
    /// Plan. Ermoeglicht "neu rechnen": der Assistent liest die urspruenglich
    /// gewaehlten Trainingsarten zurueck, statt sie erneut abzufragen.
    /// Gleiches Raw+Computed-Prinzip wie
    /// `UserBodyProfile.equipmentPreferencesRaw`.
    public var generatorInputRaw: String?

    /// Handoff "Lauf-Coaching - Machbarkeits-Check": Herkunft dieses Plans.
    /// Default `.manual`, weil das die einzige Herkunft ist, die kein
    /// Instantiator explizit setzt (Template-Adopt/Leerer-Plan gehen nicht
    /// ueber `PlanGeneratorInstantiator`). Gleiches Raw+Computed-Prinzip wie
    /// `UserBodyProfile.cardioGoalRaw`.
    public var generationSourceRaw: String = GenerationSource.manual.rawValue

    @Relationship(deleteRule: .cascade, inverse: \TrainingDay.plan)
    public var days: [TrainingDay] = []

    /// Typisierter Zugriff auf `generatorInputRaw`. Getter dekodiert JSON;
    /// liefert `nil` still (kein Crash) wenn der Plan kein Wizard-Plan ist
    /// oder das JSON aus irgendeinem Grund nicht mehr decodierbar ist.
    public var generatorInput: PlanGeneratorInput? {
        get {
            guard let raw = generatorInputRaw, let data = raw.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(PlanGeneratorInput.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                generatorInputRaw = nil
                return
            }
            generatorInputRaw = String(data: data, encoding: .utf8)
        }
    }

    public var generationSource: GenerationSource {
        get { GenerationSource(rawValue: generationSourceRaw) ?? .manual }
        set { generationSourceRaw = newValue.rawValue }
    }

    public init(
        name: String = "",
        customName: String? = nil,
        programType: String = "",
        descriptionText: String = "",
        weeks: Int = 12,
        isActive: Bool = false,
        targetEnvironment: EnvironmentType = .gym,
        isTemplate: Bool = false,
        localizationKey: String? = nil,
        generatorInputRaw: String? = nil,
        generationSource: GenerationSource = .manual
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
        self.generatorInputRaw = generatorInputRaw
        self.generationSourceRaw = generationSource.rawValue
    }
}
#endif
