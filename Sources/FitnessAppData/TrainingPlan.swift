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

    /// P6.1 (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md, "Plan-Versionierung &
    /// Datenqualitaet"): Zeitanker fuer den Beginn der AKTUELLEN
    /// Aktiv-Periode dieses Plans — die Grundlage, ab der ein spaeterer
    /// Soll-Ist-Teilnahmevergleich (P6.2) ueberhaupt erst "geplante
    /// Gelegenheiten" zaehlen darf. `nil` heisst ausdruecklich "unbekannt",
    /// NIEMALS "nie aktiviert" — additiv auf Bestandsplaenen vor diesem
    /// Feld (Lightweight-Migration, identisches Prinzip wie
    /// `localizationKey`). Es gibt bewusst KEIN erfundenes Backfill-Datum:
    /// ein Plan, der vor P6.1 aktiviert wurde, bleibt `nil`, bis er das
    /// naechste Mal (re-)aktiviert wird — alles andere waere ein
    /// erfundenes historisches Startdatum.
    ///
    /// Mehrere gleichzeitig aktive Plaene sind im Produkt ausdruecklich
    /// vorgesehen (Task #201/#202) — dieses Feld ist bewusst PRO PLAN, kein
    /// globaler "seit wann laeuft der eine aktive Plan"-Zeitpunkt.
    ///
    /// Wird NICHT automatisch bei jedem `isActive`-Schreibzugriff
    /// fortgeschrieben (SwiftData-`@Model`-Properties haben keine
    /// verlaesslichen Observer) — jeder Aufrufer, der einen Plan NEU
    /// aktiviert, muss diesen Zeitpunkt selbst setzen (siehe
    /// `PlanEditorView.setActive(_:)` fuer die manuelle UI-Reaktivierung;
    /// der Init unten deckt den Erzeugt-bereits-aktiv-Fall automatisch ab).
    /// Ein Import aus einem Backup setzt das Feld explizit auf den
    /// gespeicherten Wert (oder `nil` bei einem Backup von vor P6.1) —
    /// NIE auf "jetzt", das waere ebenfalls ein erfundenes Datum.
    public var activatedAt: Date?
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
    /// alle Uebungen progressen erst, wenn der letzte Satz mindestens
    /// `override` Wiederholungen in Reserve hatte (`lastSet.rir >= override`).
    /// Beispiel: `override = 3` verlangt sowohl bei Compounds als auch bei
    /// Isolation RIR>=3 — strenger Modus.
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
        generationSource: GenerationSource = .manual,
        // P6.1: explizit statt nur abgeleitet, damit ein Backup-Import den
        // tatsaechlich gespeicherten Zeitpunkt (oder `nil` bei einem
        // Backup von vor P6.1) durchreichen kann, ohne vom
        // Auto-"jetzt"-Default ueberschrieben zu werden.
        activatedAt: Date? = nil
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
        // P6.1: ein neu erzeugter, bereits aktiver Plan wird JETZT aktiviert
        // — kein erfundenes Datum, sondern der tatsaechliche Erzeugungs-
        // zeitpunkt. Ein expliziter `activatedAt`-Wert (Backup-Import) gewinnt
        // immer, auch wenn er `nil` ist (deshalb `??`, nicht ein zweiter
        // optionaler Parameter mit anderem Defaultverhalten).
        self.activatedAt = activatedAt ?? (isActive ? Date() : nil)
    }
}

extension TrainingPlan {
    /// System-Name und Katalog-Schluessel eines vom Nutzer frisch angelegten,
    /// leeren Plans ("Neuer Plan" / "New Plan" / "Yeni Plan"). Beide Seiten
    /// muessen dasselbe Paar kennen: `PlansListView.createNewPlan` legt den
    /// Plan damit an, `LibrarySeeder.backfillCustomNamesIfNeeded` darf ihn
    /// nicht als Nutzer-Umbenennung werten (sonst friert der deutsche Name
    /// beim naechsten App-Start als `customName` fest).
    public static let blankPlanName = "Neuer Plan"
    public static let blankPlanLocalizationKey = "plans.new"
}
#endif
