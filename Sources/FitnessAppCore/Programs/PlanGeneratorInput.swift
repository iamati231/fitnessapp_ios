import Foundation

/// README 2.20: "Trainingsart" fuer den Plan-Generator ("Plan bauen"). Kein
/// Feld in der Uebungsbibliothek - eine reine Wizard-Vokabel, die der
/// Generator auf Filterkriterien abbildet: die Kraft-Kinds mappen 1:1
/// auf `Equipment`-Faelle, die zwei Cardio-Kinds haben keine Entsprechung
/// in der Library (siehe `PlanGenerator.cardioCandidates`, das ueber
/// `isCardio` + Lauf-Zonen-Namen statt Equipment filtert).
///
/// writing-block.md Punkt 3.2: `.cable`/`.band` haben weiterhin KEINEN
/// Fall - der Katalog deckt fuer `.cable` keine einzige Bein-Uebung ab
/// (0 von 19 Cable-Eintraegen fuer Quads/Hamstrings/Waden) und fuer
/// `.band` nur 6 Uebungen über 4 von 10 Muskelgruppen (Brust/Schultern/
/// Trizeps/Core/Hamstrings/Waden fehlen komplett) - ein eigener
/// `TrainingTypeKind` wuerde dort nur eine andere Form desselben
/// "fehlende Ausstattungskategorie wird stillschweigend durch etwas
/// anderes ersetzt"-Problems erzeugen, das dieses Ticket beheben soll.
/// `.machine` hat die mit Abstand beste Abdeckung (28 Uebungen, 9 von
/// 10 Muskelgruppen, nur Gesaess fehlt) und bekommt deshalb als erstes
/// einen eigenen Fall.
public enum TrainingTypeKind: String, Codable, Sendable, CaseIterable {
    case barbell
    case dumbbell
    case kettlebell
    case machine
    case bodyweight
    case running
    case cycling

    public var isCardio: Bool {
        self == .running || self == .cycling
    }

    /// `nil` fuer die beiden Cardio-Kinds - dort filtert der Generator
    /// stattdessen ueber `isCardio` + Namens-Zugehoerigkeit.
    public var equipmentFilter: Equipment? {
        switch self {
        case .barbell:    return .barbell
        case .dumbbell:   return .dumbbell
        case .kettlebell: return .kettlebell
        case .machine:    return .machine
        case .bodyweight: return .bodyweight
        case .running, .cycling: return nil
        }
    }

    /// Lokalisierungs-KEY fuer die Schritt-1-Auswahlzeile (nicht aufgeloester
    /// Text - `FitnessAppCore` hat kein `Bundle.module`, siehe
    /// `PlanGenerator`-Datei-Kommentar). Die Wizard-UI in FitnessAppUI loest
    /// das via `String(localized: String.LocalizationValue(kind.titleKey), bundle: .module)`
    /// auf. Getrennt von `PlanGenerator`s internen, hartcodiert-deutschen
    /// Tages-Titel-Woertern (`germanTypeLabel`) - dort geht es um bereits
    /// erzeugte Plan-Inhalte (System-Name-Konvention), hier um die
    /// UI-Auswahlliste selbst (soll wie jede andere Auswahlliste EN/TR
    /// zeigen).
    public var titleKey: String {
        switch self {
        case .barbell:    return "planBuilder.type.barbell"
        case .dumbbell:   return "planBuilder.type.dumbbell"
        case .kettlebell: return "planBuilder.type.kettlebell"
        case .machine:    return "planBuilder.type.machine"
        case .bodyweight: return "planBuilder.type.bodyweight"
        case .running:    return "planBuilder.type.running"
        case .cycling:    return "planBuilder.type.cycling"
        }
    }
}

/// README 2.20: eine Trainingsart-Auswahl aus Schritt 1 des Assistenten -
/// "3 Tage Kettlebell, 45 Min., Geuebt".
public struct PlanGeneratorTypeSelection: Codable, Sendable, Hashable {
    public let kind: TrainingTypeKind
    public let daysPerWeek: Int
    public let sessionDurationMinutes: Int
    public let experience: DifficultyLevel

    /// README 2.35: nur fuer `.running`/`.cycling` abgefragt (Schritt 1 blendet
    /// den Picker fuer die vier Kraft-Arten aus) - `nil` heisst "Saetze & Wdh."
    /// (heutiges Verhalten, unveraendert). `Optional` mit Default `nil` decodiert
    /// bei fehlendem JSON-Key automatisch zu `nil`, also bleiben bereits
    /// gespeicherte `generatorInputRaw`-Snapshots (vor diesem Feld) fuer "neu
    /// rechnen" ohne Migration lesbar.
    public let timeFormat: WorkoutTimeFormat?

    /// Device-Bugreport ("Plan wird nach Geraeteart statt Trainingstagen
    /// aufgeteilt"): mehrere gewaehlte Kraft-Gerätearten (z. B. Kurzhantel +
    /// Kettlebell) sollen EINEN gemeinsamen Uebungspool fuer alle Tage dieser
    /// Selection bilden, statt dass jede Geraeteart ihre eigenen exklusiven
    /// Tage bekommt. `nil`/leer heisst: nur `kind.equipmentFilter` gilt
    /// (unveraendertes Verhalten bei genau einer Geraeteart). Wie
    /// `timeFormat` oben decodiert ein fehlender Key in bereits gespeicherten
    /// `generatorInputRaw`-Snapshots automatisch zu `nil` - "Neu rechnen"
    /// bleibt fuer alte Plaene ohne Migration lesbar.
    public let equipmentPool: Set<Equipment>?

    /// Laufcoaching-Plan-Integration (Task 2/3): Baseline aus dem Profil fuer
    /// baseline-bewusste Pace-Angaben auf generierten Easy-/Tempo-Lauf-Tagen
    /// (siehe `PlanGenerator.cardioCandidates`). `nil` heisst "keine Baseline
    /// bekannt" - heutiges Verhalten (kein `targetPaceMinutesPerKm` auf der
    /// erzeugten `ExerciseSpec`), unveraendert. Wie `timeFormat`/`equipmentPool`
    /// oben decodiert ein fehlender Key in bereits gespeicherten
    /// `generatorInputRaw`-Snapshots automatisch zu `nil` - "Neu rechnen"
    /// bleibt fuer alte Plaene ohne Migration lesbar.
    public let cardioRunProfile: CardioRunProfile?

    public init(
        kind: TrainingTypeKind,
        daysPerWeek: Int,
        sessionDurationMinutes: Int,
        experience: DifficultyLevel,
        timeFormat: WorkoutTimeFormat? = nil,
        equipmentPool: Set<Equipment>? = nil,
        cardioRunProfile: CardioRunProfile? = nil
    ) {
        self.kind = kind
        self.daysPerWeek = daysPerWeek
        self.sessionDurationMinutes = sessionDurationMinutes
        self.experience = experience
        self.timeFormat = timeFormat
        self.equipmentPool = equipmentPool
        self.cardioRunProfile = cardioRunProfile
    }
}

/// README 2.20: gesammelte Antworten aus Schritt 1+2 des "Plan bauen"-
/// Assistenten. Wird als JSON auf `TrainingPlan.generatorInputRaw`
/// gespeichert, damit "neu rechnen" spaeter weiss, wonach gerechnet wurde -
/// gleiches Prinzip wie die `*Snapshot`-Felder auf `WorkoutSession`/
/// `ExerciseLog` (JSON statt Struct-Relationship, weil SwiftData keine
/// Codable-Structs direkt als Attribut speichert).
public struct PlanGeneratorInput: Codable, Sendable, Hashable {
    public let selections: [PlanGeneratorTypeSelection]
    public let equipmentPreferences: Set<Equipment>
    public let usesFixedWeekdays: Bool
    /// Nur relevant wenn `usesFixedWeekdays == true`. Apple-Calendar-Schema
    /// (1 = Sonntag ... 7 = Samstag), gleiche Konvention wie
    /// `ProgramInstantiator.instantiate(selectedWeekdays:)`.
    public let fixedWeekdays: [Int]

    public init(
        selections: [PlanGeneratorTypeSelection],
        equipmentPreferences: Set<Equipment>,
        usesFixedWeekdays: Bool,
        fixedWeekdays: [Int] = []
    ) {
        self.selections = selections
        self.equipmentPreferences = equipmentPreferences
        self.usesFixedWeekdays = usesFixedWeekdays
        self.fixedWeekdays = fixedWeekdays
    }

    public var totalDaysPerWeek: Int {
        selections.reduce(0) { $0 + $1.daysPerWeek }
    }
}

/// Handoff "Lauf-Coaching - Machbarkeits-Check": Herkunft eines `TrainingPlan`.
/// Zweck ist rein die Wiedererkennung "existiert fuer dieses Ziel schon ein
/// angenommener Coach-Plan" auf Dashboard/Plan-Tab/Profil - die eigentliche
/// Unterdrueckung laeuft aber ueber den Fingerprint auf
/// `UserBodyProfile.cardioFeasibilityDismissedFingerprint`
/// (`CardioFeasibilityCalculator.suppressionFingerprint`), nicht ueber eine
/// Suche nach diesem Fall hier - siehe Kommentar dort.
public enum GenerationSource: String, Codable, Sendable, CaseIterable {
    case manual
    case planBuilder
    case cardioCoach
}
