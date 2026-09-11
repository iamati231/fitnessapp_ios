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

    /// Nur bei `timeFormat == .circuit`. Siehe `DaySpec.circuitRounds`.
    public var circuitRounds: Int?
    /// Nur bei `timeFormat == .circuit`. Siehe `DaySpec.circuitRestSeconds`.
    public var circuitRestSeconds: Int?
    /// Nur bei `timeFormat == .circuit`. Siehe `DaySpec.circuitMode`.
    public var circuitMode: CircuitRoundMode?

    /// README 2.20: Fingerprint des Tagesinhalts unmittelbar NACH der
    /// Erzeugung durch den "Plan bauen"-Assistenten. Nil = kein Wizard-Tag
    /// (oder noch nicht generiert). "Neu rechnen" vergleicht diesen
    /// gespeicherten Wert mit `currentContentFingerprint`: stimmen sie
    /// ueberein, hat der User seit der Generierung nichts an diesem Tag
    /// geaendert und der Assistent darf ihn ueberschreiben. Weicht der
    /// Live-Wert ab (User hat Uebungen editiert/verschoben/geloescht), wird
    /// der Tag beim Neu-Rechnen uebersprungen. Bewusst KEIN reaktives
    /// Dirty-Flag an den Editor-Mutationsstellen — ein Fingerprint-Vergleich
    /// kann keinen Mutationspfad "vergessen" und dadurch still Daten
    /// ueberschreiben.
    public var generationFingerprint: String?

    /// README 2.20: 1-basierter `DaySpec.sequenceIndex`, wie er bei der
    /// Erzeugung durch den "Plan bauen"-Assistenten vergeben wurde. Nil =
    /// kein Wizard-Tag. Stabiler Anker fuer "neu rechnen": `weekday` und
    /// `type` sind in `DayEditorView` frei editierbar (Wochentag tauschen,
    /// Tag zu Ruhetag machen) - danach stimmt die Montag-first-sortierte
    /// Position eines Tages nicht mehr mit seinem urspruenglichen
    /// `sequenceIndex` ueberein. `PlanGeneratorInstantiator.recalculate`
    /// matcht deshalb ueber DIESEN Wert statt ueber die Listenposition.
    public var generatorSequenceIndex: Int?

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

    /// README 2.20: deterministischer Live-Fingerprint des sichtbaren
    /// Tagesinhalts — siehe `generationFingerprint`. Nutzt bewusst
    /// `activeExercises` (nicht `exercises`): ein automatischer Equipment-
    /// Swap (Urlaubs-Modus) archiviert/reaktiviert Eintraege, ohne dass der
    /// User selbst etwas editiert hat, und soll "neu rechnen" nicht
    /// blockieren. Sortiert nach `orderIndex`, damit die reine SwiftData-
    /// Relationship-Reihenfolge (nicht garantiert stabil) keinen falschen
    /// Unterschied erzeugt; `orderIndex` selbst ist Teil des Strings, damit
    /// ein reines Umsortieren (`moveExercises`) trotzdem als Aenderung zaehlt.
    ///
    /// Deckt JEDES Feld ab, das `DayEditorView`/`ExerciseEditorView`
    /// tatsaechlich editierbar machen: Tag-`customName`, `weekday`, `type`
    /// (Wochentag tauschen bzw. zu Ruhetag machen ist genauso ein Edit wie
    /// eine Uebungs-Aenderung), sowie pro Uebung `customName`, `targetRir`,
    /// `targetDistanceKm`, `targetDurationMinutes` — gerade die beiden
    /// Cardio-Ziel-Felder sind der wahrscheinlichste Edit an einem
    /// generierten Lauf-/Rad-Tag und muessen erkannt werden, sonst
    /// verwirft "neu rechnen" sie kommentarlos. `timeFormat`/`timeCapMinutes`
    /// sowie die neuen `circuitRounds`/`circuitRestSeconds`/`circuitMode`
    /// fliessen ebenfalls ein — ein Struktur-Wechsel im Tag-Editor ist
    /// genauso ein Edit.
    public var currentContentFingerprint: String {
        let exercisePart = activeExercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map {
                [
                    $0.name, $0.customName ?? "-", "\($0.orderIndex)",
                    "\($0.sets)", "\($0.repsMin)", "\($0.repsMax)", "\($0.restSeconds)",
                    "\($0.targetRir)",
                    $0.targetDistanceKm.map { "\($0)" } ?? "-",
                    $0.targetDurationMinutes.map { "\($0)" } ?? "-"
                ].joined(separator: "|")
            }
            .joined(separator: ";")
        let timeFormatPart = timeFormat?.rawValue ?? "-"
        let timeCapPart = timeCapMinutes.map(String.init) ?? "-"
        let customNamePart = customName ?? "-"
        let circuitPart = "\(circuitRounds.map(String.init) ?? "-")|\(circuitRestSeconds.map(String.init) ?? "-")|\(circuitMode?.rawValue ?? "-")"
        return "\(exercisePart)#\(timeFormatPart)#\(timeCapPart)#\(customNamePart)#\(weekday)#\(type.rawValue)#\(circuitPart)"
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
        timeCapMinutes: Int? = nil,
        circuitRounds: Int? = nil,
        circuitRestSeconds: Int? = nil,
        circuitMode: CircuitRoundMode? = nil,
        generationFingerprint: String? = nil,
        generatorSequenceIndex: Int? = nil
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
        self.circuitRounds = circuitRounds
        self.circuitRestSeconds = circuitRestSeconds
        self.circuitMode = circuitMode
        self.generationFingerprint = generationFingerprint
        self.generatorSequenceIndex = generatorSequenceIndex
    }
}

// MARK: - Core protocol conformances

/// Lets `PlanNavigator.sortByWeekdayMondayFirst` sort `[TrainingDay]` directly
/// without the view layer projecting weekdays into a separate value array.
extension TrainingDay: WeekdayProvider {}
#endif
