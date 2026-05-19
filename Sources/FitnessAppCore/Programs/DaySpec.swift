import Foundation

/// One training day inside a `ProgramTemplate`.
///
/// DEL-088: Wochentag-unabhaengig. Templates enthalten nur Trainings-Tage,
/// sortiert nach `sequenceIndex` (1, 2, 3, ...). Beim Plan-Adopt waehlt der
/// User in einem `DayPickerSheet` echte Wochentage; der `ProgramInstantiator`
/// mappt Sequenz → Apple-Calendar-Wochentag und fuellt die restlichen Tage
/// mit `DayType.rest` auf.
public struct DaySpec: Sendable, Hashable {
    public let name: String
    public let type: DayType
    /// DEL-088: 1-basierter Index in der Trainings-Wochen-Sequenz. Erster
    /// Trainings-Tag = `1`, zweiter = `2`, etc. Templates enthalten KEINE
    /// Rest-Days mehr; `sequenceIndex` laeuft kontinuierlich 1...daysPerWeek.
    public let sequenceIndex: Int
    public let exercises: [ExerciseSpec]

    /// DEL-115: i18n-Lookup-Key fuer den Tag-Namen (Namespace `plan.day.*`).
    /// Optional — User-generierte Custom-Tage haben naturgemaess keinen Key
    /// und fallen via `DaySpec+DisplayName`-Extension auf `name` zurueck.
    /// Beim Instanziieren in `ProgramInstantiator` wird das Key NICHT auf
    /// das SwiftData-Modell propagiert: `TrainingDay.name` snapshotet den
    /// (potentiell lokalisierten) String beim Adopt-Zeitpunkt — die spaetere
    /// Sprachumschaltung greift somit nur fuer Template-Surfaces, nicht
    /// fuer bestehende Plan-Instanzen.
    public let localizationKey: String?

    public init(name: String, localizationKey: String? = nil, type: DayType, sequenceIndex: Int, exercises: [ExerciseSpec]) {
        self.name = name
        self.localizationKey = localizationKey
        self.type = type
        self.sequenceIndex = sequenceIndex
        self.exercises = exercises
    }
}
