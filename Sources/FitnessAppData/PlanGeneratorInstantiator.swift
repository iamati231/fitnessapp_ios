#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// README 2.20 "Plan bauen": Bruecke zwischen dem reinen Core-Generator
/// (`PlanGenerator`, kein SwiftData) und der bestehenden
/// `ProgramInstantiator`-Materialisierung. Baut dafuer eine wegwerfbare
/// synthetische `ProgramTemplate`-Huelle aus dem generierten `[DaySpec]` und
/// delegiert die eigentliche Insert-Arbeit an `ProgramInstantiator.instantiate`,
/// statt sie zu duplizieren - so profitiert "Plan bauen" automatisch von
/// jeder kuenftigen Aenderung an der Instanziierungs-Logik.
@MainActor
public enum PlanGeneratorInstantiator {

    /// Rechnet `input` einmal aus, instanziiert das Ergebnis als neuen
    /// aktiven Plan (gleiche Side-Effects wie jeder andere Template-Adopt,
    /// siehe `ProgramInstantiator.instantiate`) und stempelt danach jeden
    /// Trainings-Tag mit seinem Erzeugungs-Fingerprint sowie den Plan mit
    /// dem JSON-codierten `input` - beides zusammen macht `recalculate`
    /// spaeter moeglich.
    ///
    /// Liefert `nil`, wenn der Generator fuer diese Auswahl NICHTS gefunden
    /// hat (z.B. eine Ausruestung/Schwierigkeit-Kombination ohne jeden
    /// Bibliotheks-Treffer) - die Wizard-UI sollte "Plan uebernehmen" zwar
    /// bereits vorher deaktivieren, wenn `PlanGenerator.generate` leer
    /// zurueckkommt, aber diese Funktion verlaesst sich nicht darauf: ein
    /// `daysPerWeek: 0`-Template wuerde `ProgramInstantiator.defaultWeekdays`
    /// in eine ungueltige Range (`2...1`) und damit einen Crash laufen lassen.
    @discardableResult
    public static func build(from input: PlanGeneratorInput, in context: ModelContext) -> TrainingPlan? {
        let result = PlanGenerator.generate(from: input)
        guard !result.days.isEmpty else { return nil }
        let template = makeTemplate(from: result)

        let plan = ProgramInstantiator.instantiate(
            template,
            in: context,
            selectedWeekdays: resolvedWeekdays(from: input),
            userEquipment: input.equipmentPreferences
        )
        plan.generatorInput = input
        for day in plan.days where day.type != .rest {
            day.generationFingerprint = day.currentContentFingerprint
        }
        return plan
    }

    /// README 2.20 "neu rechnen": rechnet den am Plan gespeicherten
    /// `generatorInput` neu und ersetzt NUR Tage, deren Inhalt seit der
    /// letzten (Neu-)Erzeugung unveraendert ist - "ueberschreiben, aber nur
    /// unangetastete Tage", das Dokument schlaegt diese Regel selbst vor.
    /// Ein Tag gilt als unangetastet, wenn sein gespeicherter
    /// `generationFingerprint` noch exakt seinem `currentContentFingerprint`
    /// entspricht; alles andere ist ein User-Edit und bleibt stehen.
    ///
    /// Matching generierter <-> bestehender Tage laeuft rein positional
    /// (Montag-first sortiert = `sequenceIndex`-Reihenfolge, siehe
    /// `ProgramInstantiator.instantiate`s Wochentag-Zuordnung) - Tage
    /// aendern ihren Wochentag durch `recalculate` nie, nur Name/Inhalt.
    /// Kein-Op (Rueckgabe 0), wenn der Plan gar keinen `generatorInput`
    /// traegt (nicht ueber den Assistenten entstanden).
    ///
    /// Rueckgabe: Anzahl der tatsaechlich neu geschriebenen Tage.
    @discardableResult
    public static func recalculate(_ plan: TrainingPlan, in context: ModelContext) -> Int {
        guard let input = plan.generatorInput else { return 0 }
        let result = PlanGenerator.generate(from: input)

        // WICHTIG: entlang der VOLLSTAENDIGEN Liste iterieren und per Index
        // in `result.days` greifen - NICHT `existingWorkoutDays.filter(...)`
        // gegen `result.days` zippen. Sobald irgendein Tag VOR dem letzten
        // uebersprungen wird, haetten die beiden Listen unterschiedliche
        // Luecken und ein positionelles Zip wuerde jeden nachfolgenden Tag
        // mit dem FALSCHEN generierten Tag verheiraten.
        let existingWorkoutDays = PlanNavigator.sortByWeekdayMondayFirst(
            plan.days.filter { $0.type != .rest }
        )

        let (timeBasedNames, compoundNames) = ProgramInstantiator.libraryLookupNames()
        let specByName = ProgramInstantiator.libraryLookupSpecs()

        var rewritten = 0
        for (index, day) in existingWorkoutDays.enumerated() {
            // Tage-Anzahl kann seit der Erzeugung abweichen, wenn der User
            // ueber den Editor einen Ruhetag zu einem Trainingstag gemacht
            // hat (oder umgekehrt) - defensiv abbrechen statt out-of-bounds
            // zu greifen.
            guard index < result.days.count else { break }
            guard day.generationFingerprint != nil,
                  day.generationFingerprint == day.currentContentFingerprint else { continue }
            apply(
                result.days[index].spec,
                to: day,
                timeBasedNames: timeBasedNames,
                compoundNames: compoundNames,
                specByName: specByName,
                in: context
            )
            rewritten += 1
        }
        return rewritten
    }

    /// Ersetzt Name + Zeitformat + Uebungen eines Tages durch einen frisch
    /// generierten `DaySpec` und schreibt den neuen Fingerprint fest -
    /// gleiche Exercise-Anreicherung wie beim ersten Erzeugen
    /// (`ProgramInstantiator.makeExercise`), keine Zweit-Implementierung.
    private static func apply(
        _ spec: DaySpec,
        to day: TrainingDay,
        timeBasedNames: Set<String>,
        compoundNames: Set<String>,
        specByName: [String: ExerciseTemplateSpec],
        in context: ModelContext
    ) {
        for exercise in day.exercises {
            context.delete(exercise)
        }
        day.exercises = []

        day.name = spec.name
        day.customName = nil
        day.localizationKey = spec.localizationKey
        day.timeFormat = spec.timeFormat
        day.timeCapMinutes = spec.timeCapMinutes

        for (orderIndex, exerciseSpec) in spec.exercises.enumerated() {
            let exercise = ProgramInstantiator.makeExercise(
                from: exerciseSpec,
                orderIndex: orderIndex,
                timeBasedNames: timeBasedNames,
                compoundNames: compoundNames,
                librarySpecByName: specByName,
                day: day
            )
            context.insert(exercise)
        }

        day.generationFingerprint = day.currentContentFingerprint
    }

    /// `nil` (= `ProgramInstantiator` faellt auf `defaultWeekdays` zurueck)
    /// wenn Schritt 2 "Nur Reihenfolge" gewaehlt hat. Bei festen Wochentagen
    /// wird `input.fixedWeekdays` unveraendert durchgereicht - ein
    /// Anzahl-Mismatch faengt `ProgramInstantiator.instantiate` selbst
    /// defensiv ab (faellt dann seinerseits auf Defaults zurueck).
    private static func resolvedWeekdays(from input: PlanGeneratorInput) -> [Int]? {
        input.usesFixedWeekdays ? input.fixedWeekdays : nil
    }

    /// Wegwerf-Huelle, rein damit `ProgramInstantiator.instantiate`
    /// wiederverwendet werden kann. `id` ist absichtlich kein echter
    /// `ProgramTemplates.all`-Eintrag - jeder Code, der `programType` gegen
    /// die kuratierte Liste abgleicht (`LibrarySeeder`s Backfills), behandelt
    /// eine unbekannte ID bereits konservativ als "Custom-Plan ohne
    /// Template-Origin" (gleiche Kategorie wie ein manuell angelegter Plan).
    private static func makeTemplate(from result: PlanGenerator.Result) -> ProgramTemplate {
        ProgramTemplate(
            id: "planBuilder.generated",
            name: "Individueller Plan",
            tagline: "",
            descriptionText: "",
            focus: "",
            daysPerWeek: result.days.count,
            days: result.days.map(\.spec),
            targetEnvironment: .gym,
            iconSystemName: "wand.and.stars"
        )
    }
}
#endif
