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

    /// DEL-115: i18n-Lookup-Key fuer den Tag-Namen (Namespace `plan.day.*`;
    /// DEL-247 ergaenzt zusammengesetzte Keys fuer generierte Plaene, siehe
    /// `PlanGenerator`-Datei-Kommentar). Optional — User-generierte
    /// Custom-Tage haben naturgemaess keinen Key und fallen via
    /// `DaySpec+DisplayName`-Extension auf `name` zurueck. DEL-123: wird
    /// beim Instanziieren in `ProgramInstantiator` AUF
    /// `TrainingDay.localizationKey` propagiert — eine spaetere
    /// Sprachumschaltung greift damit auch fuer bereits adoptierte
    /// Plan-Instanzen, nicht nur fuer Template-Vorschauen.
    public let localizationKey: String?

    /// Zeitformat dieses Tags (AMRAP/EMOM/Auf Zeit) — `nil` fuer normales
    /// Satz/Wiederholungs-Training (der bestehende, unveraenderte Fall).
    public let timeFormat: WorkoutTimeFormat?
    /// AMRAP-Deckel bzw. EMOM-Gesamtdauer in Minuten. Bei Auf-Zeit optional
    /// als Abbruch-Deckel. `nil` wenn `timeFormat == nil` oder das Format
    /// keinen Deckel braucht.
    public let timeCapMinutes: Int?

    /// Nur bei `timeFormat == .circuit` gesetzt: Anzahl der Runden.
    public let circuitRounds: Int?
    /// Nur bei `timeFormat == .circuit` gesetzt: Pause zwischen den Runden
    /// in Sekunden.
    public let circuitRestSeconds: Int?
    /// Nur bei `timeFormat == .circuit` gesetzt: wie eine Runde als "fertig"
    /// erkannt wird.
    public let circuitMode: CircuitRoundMode?

    /// Paket 2: nur bei `timeFormat == .enduranceIntervals` gesetzt. Siehe
    /// `WorkoutTimeFormat.enduranceIntervals`-Doku fuer die Bedeutung jedes
    /// Felds. `enduranceWorkDurationSeconds`/`enduranceWorkDistanceKm`: nie
    /// beide zugleich gesetzt (ein Belastungs-Abschnitt hat GENAU eine
    /// Zielart — Zeit, Strecke, oder "offen" wenn beide `nil` sind), gleiches
    /// Prinzip wie `ExerciseSpec.targetDistanceKm`/`targetDurationMinutes`.
    public let enduranceWarmupDurationSeconds: Int?
    public let enduranceCooldownDurationSeconds: Int?
    public let enduranceIntervalRounds: Int?
    public let enduranceWorkDurationSeconds: Int?
    public let enduranceWorkDistanceKm: Double?
    /// Erholung bleibt in dieser ersten Version bewusst zeitbasiert (alle
    /// bekannten Beispiele zeigen reine Zeit-Erholung zwischen Belastungen).
    public let enduranceRestDurationSeconds: Int?
    /// Nur die beiden Cardio-Faelle (`.running`/`.cycling`) sind gueltig.
    /// `nil` = nicht festgelegt - siehe `TrainingDay.enduranceSportKind`-Doku
    /// (niemals aus `name` zurueckgeraten).
    public let enduranceSportKind: TrainingTypeKind?

    public init(
        name: String,
        localizationKey: String? = nil,
        type: DayType,
        sequenceIndex: Int,
        exercises: [ExerciseSpec],
        timeFormat: WorkoutTimeFormat? = nil,
        timeCapMinutes: Int? = nil,
        circuitRounds: Int? = nil,
        circuitRestSeconds: Int? = nil,
        circuitMode: CircuitRoundMode? = nil,
        enduranceWarmupDurationSeconds: Int? = nil,
        enduranceCooldownDurationSeconds: Int? = nil,
        enduranceIntervalRounds: Int? = nil,
        enduranceWorkDurationSeconds: Int? = nil,
        enduranceWorkDistanceKm: Double? = nil,
        enduranceRestDurationSeconds: Int? = nil,
        enduranceSportKind: TrainingTypeKind? = nil
    ) {
        self.name = name
        self.localizationKey = localizationKey
        self.type = type
        self.sequenceIndex = sequenceIndex
        self.exercises = exercises
        self.timeFormat = timeFormat
        self.timeCapMinutes = timeCapMinutes
        self.circuitRounds = circuitRounds
        self.circuitRestSeconds = circuitRestSeconds
        self.circuitMode = circuitMode
        self.enduranceWarmupDurationSeconds = enduranceWarmupDurationSeconds
        self.enduranceCooldownDurationSeconds = enduranceCooldownDurationSeconds
        self.enduranceIntervalRounds = enduranceIntervalRounds
        self.enduranceWorkDurationSeconds = enduranceWorkDurationSeconds
        self.enduranceWorkDistanceKm = enduranceWorkDistanceKm
        self.enduranceRestDurationSeconds = enduranceRestDurationSeconds
        self.enduranceSportKind = enduranceSportKind
    }
}
